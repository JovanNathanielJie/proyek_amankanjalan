import 'dart:io';
import 'dart:convert'; // Ditambahkan untuk konversi Base64
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // Dihapus karena tidak lagi digunakan
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({Key? key}) : super(key: key);

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  String _selectedUrgency = 'RENDAH';
  String _selectedCategory = 'Lampu Mati'; 
  
  XFile? _imageFile; 
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  bool _isDataLoading = true;
  bool _isSearchingLocation = false; 
  bool _isProcessingTap = false; 

  String currentUserId = "";
  String currentUserName = "Memuat nama...";

  // --- MAP PREVIEW VARIABLES ---
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  // Titik awal peta (Palembang)
  final LatLng _defaultCenter = const LatLng(-2.990934, 104.756554);

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Lampu Mati', 'icon': Icons.lightbulb_outline, 'color': Colors.orange},
    {'name': 'Area Gelap', 'icon': Icons.dark_mode_outlined, 'color': Colors.purple},
    {'name': 'Rawan Kecelakaan', 'icon': Icons.warning_amber_rounded, 'color': Colors.red},
    {'name': 'Kemacetan', 'icon': Icons.traffic_outlined, 'color': Colors.blue},
    {'name': 'Jalan Rusak', 'icon': Icons.broken_image_outlined, 'color': Colors.brown},
    {'name': 'Rambu Rusak', 'icon': Icons.construction_outlined, 'color': Colors.indigo},
    {'name': 'Banjir', 'icon': Icons.water_drop_outlined, 'color': Colors.cyan},
    {'name': 'Lainnya', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          currentUserId = user.uid;
        });
        
        DataSnapshot snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/fullName').get();
        if (snapshot.exists) {
          setState(() {
            currentUserName = snapshot.value.toString();
          });
        } else {
          setState(() {
            currentUserName = "Warga AmankanJalan";
          });
        }
      }
    } catch (e) {
      print("Gagal mengambil profil pelapor: $e");
    } finally {
      setState(() {
        _isDataLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 30,  
        maxWidth: 1024,    
        maxHeight: 1024,   
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil gambar: $e')),
      );
    }
  }

  // --- FUNGSI MENCARI KOORDINAT DARI TEKS (GEOCODING PINTAR) ---
  Future<void> _searchLocationFromText() async {
    String inputQuery = _locationController.text.trim();
    if (inputQuery.isEmpty) return;

    setState(() => _isSearchingLocation = true);

    // Bersihkan format (Ubah "jl." jadi "Jalan ")
    String formattedQuery = inputQuery.replaceAll(RegExp(r'(?i)\bjl\.\s*|\bjl\s+'), 'Jalan ');

    // Tambahkan konteks kota & negara secara otomatis
    if (!formattedQuery.toLowerCase().contains("palembang")) {
      formattedQuery = "$formattedQuery, Palembang";
    }
    if (!formattedQuery.toLowerCase().contains("indonesia")) {
      formattedQuery = "$formattedQuery, Indonesia";
    }

    try {
      // PERCOBAAN 1: Cari dengan format yang sudah diperbaiki
      List<Location> locations = await locationFromAddress(formattedQuery);
      
      if (locations.isNotEmpty) {
        final newLoc = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _selectedLocation = newLoc;
        });
        _mapController.move(newLoc, 16.0);
      }
    } catch (e) {
      // PERCOBAAN 2: Jika gagal, coba dengan input asli + Indonesia
      try {
         List<Location> fallbackLocations = await locationFromAddress("$inputQuery, Indonesia");
         if (fallbackLocations.isNotEmpty) {
            final newLoc = LatLng(fallbackLocations.first.latitude, fallbackLocations.first.longitude);
            setState(() {
              _selectedLocation = newLoc;
            });
            _mapController.move(newLoc, 16.0);
            return;
         }
      } catch (fallbackError) {
         // Lanjut ke error di bawah
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat sulit ditemukan. Gunakan format "Jalan [Nama], [Kecamatan]" atau sentuh titik di peta.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  // --- FUNGSI MENCARI ALAMAT DARI TITIK PETA (REVERSE GEOCODING) ---
  Future<void> _handleMapTap(TapPosition tapPosition, LatLng point) async {
    if (_isProcessingTap) return;
    
    setState(() {
      _selectedLocation = point;
      _isSearchingLocation = true;
      _isProcessingTap = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String address = "";
        if (p.street != null && p.street!.isNotEmpty) address += "${p.street}, ";
        if (p.subLocality != null && p.subLocality!.isNotEmpty) address += "${p.subLocality}, ";
        if (p.locality != null && p.locality!.isNotEmpty) address += p.locality!;
        
        _locationController.text = address.replaceAll(RegExp(r', $'), ''); 
      } else {
         _locationController.text = "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
      }
    } catch (e) {
      _locationController.text = "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
          _isProcessingTap = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (_titleController.text.trim().isEmpty || 
        _descController.text.trim().isEmpty || 
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi judul, deskripsi, dan lokasi.')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap konfirmasi titik lokasi di peta.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;

      // --- LOGIKA BARU: KONVERSI GAMBAR KE TEKS BASE64 ---
      if (_imageFile != null) {
        // Membaca file gambar sebagai byte data
        List<int> imageBytes = await _imageFile!.readAsBytes();
        // Mengubah byte data menjadi string teks Base64 yang panjang
        imageUrl = base64Encode(imageBytes);
      }

      String coordinates = '${_selectedLocation!.latitude},${_selectedLocation!.longitude}';

      await FirebaseFirestore.instance.collection('reports').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'coordinates': coordinates,
        'urgency': _selectedUrgency,
        'category': _selectedCategory,
        'imageUrl': imageUrl, // Menyimpan teks Base64, bukan link URL
        'timestamp': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'status': 'Aktif',
        'reporterId': currentUserId, 
        'reporterName': currentUserName, 
        'supportedBy': [], 
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil dikirim!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDataLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F0F5),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E1E96)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E96),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buat Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- KATEGORI ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kategori Laporan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category['name'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category['name']),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? category['color'].withOpacity(0.15) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? category['color'] : Colors.transparent, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(category['icon'], color: category['color'], size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  category['name'], textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? category['color'] : Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- DETAIL & LOKASI ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detail & Lokasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 12),

                    _buildLabel('Judul Laporan *'),
                    _buildTextField(controller: _titleController, hint: 'Contoh: Lampu jalan mati di...'),
                    const SizedBox(height: 16),
                    
                    _buildLabel('Deskripsi *'),
                    TextField(
                      controller: _descController,
                      maxLength: 400,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan kondisi dan tingkat bahaya...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true, fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- SECTION LOKASI PREVIEW ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Titik Lokasi *'),
                        if (_isSearchingLocation) 
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              hintText: 'Ketik alamat...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF1E1E96)),
                              filled: true, fillColor: const Color(0xFFF8F9FA),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _searchLocationFromText(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: const Color(0xFF1E1E96), borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: _searchLocationFromText,
                            tooltip: 'Cari Lokasi',
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 12.0),
                      child: Text('💡 Tips: Anda juga bisa menyentuh dan menggeser peta di bawah ini untuk menentukan titik pastinya.', 
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                    ),
                    
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _defaultCenter,
                            initialZoom: 13.0,
                            onTap: _handleMapTap,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.amankanjalan.app',
                            ),
                            if (_selectedLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLocation!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                                    alignment: Alignment.topCenter,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Tingkat Urgensi *'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUrgency,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1E1E96)),
                          items: ['RENDAH', 'SEDANG', 'DARURAT'].map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (newValue) => setState(() => _selectedUrgency = newValue!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- FOTO SECTION ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: _buildPhotoSection(),
              ),
              const SizedBox(height: 24),

              // --- SUBMIT BUTTON ---
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitReport,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isLoading ? 'Mengirim...' : 'Kirim Laporan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E96),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, IconData? icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF1E1E96)) : null,
        filled: true, fillColor: const Color(0xFFF8F9FA), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Foto Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Tambahkan foto untuk memperkuat laporan (opsional)', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        
        if (_imageFile != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(_imageFile!.path, height: 180, width: double.infinity, fit: BoxFit.cover)
                    : Image.file(File(_imageFile!.path), height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _imageFile = null),
                  child: const CircleAvatar(backgroundColor: Colors.black54, radius: 14, child: Icon(Icons.close, color: Colors.white, size: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E1E96)),
                label: const Text('Kamera', style: TextStyle(color: Color(0xFF1E1E96))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF1E1E96)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined, color: Color(0xFF1E1E96)),
                label: const Text('Galeri', style: TextStyle(color: Color(0xFF1E1E96))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF1E1E96)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
  String _selectedCategory = 'Lampu Mati'; // Kategori default
  
  XFile? _imageFile; 
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  bool _isDataLoading = true;

  String currentUserId = "";
  String currentUserName = "Memuat nama...";

  // Daftar kategori laporan dengan icon
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
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 30,  // Naikkan kompresi dari 70 menjadi 30 untuk file lebih kecil
        maxWidth: 1024,    // Resize lebar maksimal 1024px
        maxHeight: 1024,   // Resize tinggi maksimal 1024px
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

  Future<void> _submitReport() async {
    if (_titleController.text.trim().isEmpty || 
        _descController.text.trim().isEmpty || 
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi judul, deskripsi, dan lokasi.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;

      // --- LOGIKA UPLOAD GAMBAR WEB & MOBILE ---
      if (_imageFile != null) {
        String fileName = 'reports/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        
        UploadTask uploadTask;

        if (kIsWeb) {
          // Jika berjalan di Web, gunakan putData (membaca file sebagai bytes)
          uploadTask = storageRef.putData(await _imageFile!.readAsBytes());
        } else {
          // Jika di Mobile (Android/iOS), gunakan putFile
          uploadTask = storageRef.putFile(File(_imageFile!.path));
        }
        
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Gunakan kategori yang dipilih user
      String category = _selectedCategory;

      await FirebaseFirestore.instance.collection('reports').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'urgency': _selectedUrgency,
        'category': category,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'status': 'Aktif',
        'reporterId': currentUserId, // Otomatis ID user asli yang login
        'reporterName': currentUserName, // Otomatis Nama asli dari Realtime Database
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
    // Tahan UI dengan indikator loading jika data user belum berhasil ditarik
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
              // --- KATEGORI LAPORAN SECTION ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kategori Laporan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category['name'];
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? category['color'].withOpacity(0.15) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? category['color'] : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  category['icon'],
                                  color: category['color'],
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category['name'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? category['color'] : Colors.grey.shade700,
                                  ),
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

              // --- DETAIL LAPORAN SECTION ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Laporan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),

                    // Judul Laporan
                    _buildLabel('Judul Laporan *'),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'Contoh: Lampu jalan mati di...',
                    ),
                    const SizedBox(height: 16),
                    
                    // Deskripsi
                    _buildLabel('Deskripsi *'),
                    Stack(
                      children: [
                        TextField(
                          controller: _descController,
                          maxLength: 400,
                          maxLines: 4,
                          onChanged: (value) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Jelaskan kondisi dan tingkat bahaya...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            counterText: '',
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 12,
                          child: Text(
                            '${_descController.text.length}/400',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Lokasi
                    _buildLabel('Lokasi *'),
                    _buildTextField(
                      controller: _locationController,
                      hint: 'Masukkan alamat lokasi...',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Tingkat Urgensi
                    _buildLabel('Tingkat Urgensi *'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUrgency,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1E1E96)),
                          items: ['RENDAH', 'SEDANG', 'DARURAT'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedUrgency = newValue!;
                            });
                          },
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24), 
                  ),
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
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, IconData? icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF1E1E96)) : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FA), 
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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
                    ? Image.network(
                        _imageFile!.path,
                        height: 180, 
                        width: double.infinity, 
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_imageFile!.path),
                        height: 180, 
                        width: double.infinity, 
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _imageFile = null),
                  child: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 14,
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
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
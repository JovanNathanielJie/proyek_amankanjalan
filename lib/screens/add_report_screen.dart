import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Menambahkan deteksi Web
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  
  // MENGUBAH File menjadi XFile agar kompatibel dengan Web
  XFile? _imageFile; 
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;

  final String currentUserId = "user_123";
  final String currentUserName = "Rissa";

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
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile; // Menyimpan XFile langsung
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

      String category = 'Umum';
      String textToLower = '${_titleController.text} ${_descController.text}'.toLowerCase();
      if (textToLower.contains('lampu') || textToLower.contains('penerangan')) {
        category = 'Lampu Mati';
      } else if (textToLower.contains('kecelakaan') || textToLower.contains('bahaya')) {
        category = 'Rawan Kecelakaan';
      } else if (textToLower.contains('gelap')) {
        category = 'Area Gelap';
      }

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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Judul Laporan *'),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'Contoh: Tikungan Berbahaya Tanpa Rambu',
                    ),
                    const SizedBox(height: 16),
                    
                    _buildLabel('Deskripsi *'),
                    TextField(
                      controller: _descController,
                      maxLength: 400,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan kondisi secara detail...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildLabel('Lokasi *'),
                    _buildTextField(
                      controller: _locationController,
                      hint: 'Masukkan alamat lokasi...',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),

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

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildPhotoSection(),
              ),
              const SizedBox(height: 24),

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
        
        // --- LOGIKA TAMPILAN PREVIEW WEB & MOBILE ---
        if (_imageFile != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(
                        _imageFile!.path, // Web menggunakan network blob URL
                        height: 180, 
                        width: double.infinity, 
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_imageFile!.path), // HP menggunakan File io
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
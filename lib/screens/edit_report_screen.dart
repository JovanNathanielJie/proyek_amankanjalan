import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditReportScreen extends StatefulWidget {
  final String docId;
  final String initialTitle;
  final String initialDesc;
  final String initialLocation;
  final String initialUrgency;

  const EditReportScreen({
    Key? key,
    required this.docId,
    required this.initialTitle,
    required this.initialDesc,
    required this.initialLocation,
    required this.initialUrgency,
  }) : super(key: key);

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late String _selectedUrgency;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mengisi form dengan data lama
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDesc);
    _locationController = TextEditingController(text: widget.initialLocation);
    _selectedUrgency = widget.initialUrgency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateReport() async {
    if (_titleController.text.trim().isEmpty || 
        _descController.text.trim().isEmpty || 
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua bidang.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Deteksi ulang kategori berdasarkan teks baru
      String category = 'Umum';
      String textToLower = '${_titleController.text} ${_descController.text}'.toLowerCase();
      if (textToLower.contains('lampu') || textToLower.contains('penerangan')) {
        category = 'Lampu Mati';
      } else if (textToLower.contains('kecelakaan') || textToLower.contains('bahaya') || textToLower.contains('lobang')) {
        category = 'Rawan Kecelakaan';
      } else if (textToLower.contains('gelap')) {
        category = 'Area Gelap';
      }

      // Update dokumen ke Firestore
      await FirebaseFirestore.instance.collection('reports').doc(widget.docId).update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'urgency': _selectedUrgency,
        'category': category,
        // Jika kamu memasukkan link ke kolom lokasi, kita bisa salin juga ke coordinates
        'coordinates': _locationController.text.trim(), 
      });

      if (mounted) {
        Navigator.pop(context); // Kembali ke halaman detail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil diperbarui!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
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
        title: const Text('Edit Laporan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Judul Laporan *'),
                    _buildTextField(controller: _titleController, hint: 'Contoh: Jalan Berlobang'),
                    const SizedBox(height: 16),
                    
                    _buildLabel('Deskripsi *'),
                    TextField(
                      controller: _descController,
                      maxLength: 400,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan kondisi...',
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildLabel('Lokasi (Atau Link Map) *'),
                    _buildTextField(controller: _locationController, hint: 'Masukkan alamat atau link...', icon: Icons.location_on_outlined),
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
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateReport,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Perubahan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E96),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
              ),
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
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF1E1E96)) : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FA), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({Key? key}) : super(key: key);

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = ""; 
  String _selectedUrgency = "RENDAH"; // Nilai default untuk dropdown
  bool _isLoading = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Lampu Mati', 'icon': Icons.lightbulb_outline, 'color': Colors.orange},
    {'name': 'Area Gelap', 'icon': Icons.dark_mode_outlined, 'color': Colors.purple},
    {'name': 'Rawan Kecelakaan', 'icon': Icons.warning_amber_rounded, 'color': Colors.red},
    {'name': 'Kemacetan', 'icon': Icons.directions_car_filled_outlined, 'color': Colors.blue},
    {'name': 'Jalan Rusak', 'icon': Icons.settings_input_component_outlined, 'color': Colors.brown},
    {'name': 'Rambu Rusak', 'icon': Icons.not_interested_outlined, 'color': Colors.redAccent},
    {'name': 'Banjir/Genangan', 'icon': Icons.water_drop_outlined, 'color': Colors.blueAccent},
    {'name': 'Lainnya', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  // Opsi untuk Dropdown Urgensi
  final List<String> _urgencies = ['RENDAH', 'SEDANG', 'DARURAT'];

  void _submitToFirestore() async {
    // Validasi form dan kategori 
    if (_selectedCategory.isEmpty || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'category': _selectedCategory,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'urgency': _selectedUrgency, // Sekarang mengambil dari input dropdown user
        'upvotes': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Langsung tutup halaman (kembali ke beranda) tanpa SnackBar
      if (mounted) {
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint("Gagal mengirim laporan: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Buat Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E96),
        foregroundColor: Colors.white, 
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SEKSI KATEGORI ---
                    _buildSectionCard(
                      title: "Kategori Laporan",
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.0, 
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedCategory == _categories[index]['name'];
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedCategory = _categories[index]['name']);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF1E1E96) : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_categories[index]['icon'], color: _categories[index]['color'], size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _categories[index]['name'],
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- SEKSI DETAIL LAPORAN ---
                    _buildSectionCard(
                      title: "Detail Laporan",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Judul Laporan *"),
                          TextFormField(
                            controller: _titleController,
                            decoration: _inputDecoration("Contoh: Lampu jalan mati di..."),
                            validator: (v) => v!.isEmpty ? "Judul wajib diisi" : null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Deskripsi *"),
                          TextFormField(
                            controller: _descController,
                            maxLines: 4,
                            maxLength: 400,
                            decoration: _inputDecoration("Jelaskan kondisi dan tingkat bahaya..."),
                            validator: (v) => v!.isEmpty ? "Deskripsi wajib diisi" : null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Lokasi *"),
                          TextFormField(
                            controller: _locationController,
                            decoration: _inputDecoration(
                              "Masukkan alamat lokasi...",
                              prefixIcon: Icons.location_on_outlined,
                            ),
                            validator: (v) => v!.isEmpty ? "Lokasi wajib diisi" : null,
                          ),
                          
                          // --- TAMBAHAN DROPDOWN URGENSI ---
                          const SizedBox(height: 16),
                          _buildLabel("Tingkat Urgensi *"),
                          DropdownButtonFormField<String>(
                            value: _selectedUrgency,
                            decoration: _inputDecoration("Pilih tingkat urgensi"),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1E1E96)),
                            items: _urgencies.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedUrgency = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- SEKSI FOTO LOKASI ---
                    _buildSectionCard(
                      title: "Foto Lokasi",
                      subtitle: "Tambahkan foto untuk memperkuat laporan (opsional)",
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildImageButton(Icons.camera_alt_outlined, "Kamera"),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildImageButton(Icons.image_outlined, "Galeri"),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- TOMBOL KIRIM ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _submitToFirestore,
                        icon: const Icon(Icons.send),
                        label: const Text("Kirim Laporan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E96),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionCard({required String title, String? subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF1E1E96)) : null,
      filled: true,
      fillColor: const Color(0xFFF8F9FE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E1E96))),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    );
  }

  Widget _buildImageButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {}, 
      icon: Icon(icon, color: const Color(0xFF1E1E96)),
      label: Text(label, style: const TextStyle(color: Color(0xFF1E1E96))),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Color(0xFF1E1E96)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
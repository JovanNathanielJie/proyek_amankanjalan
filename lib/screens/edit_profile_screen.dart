import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentFullName;
  final String currentUsername;
  final String currentPhoneNumber;

  const EditProfileScreen({
    Key? key,
    required this.currentFullName,
    required this.currentUsername,
    required this.currentPhoneNumber,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneNumberController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mengisi form dengan data saat ini yang dilempar dari ProfileScreen
    _fullNameController = TextEditingController(text: widget.currentFullName);
    _usernameController = TextEditingController(text: widget.currentUsername);
    _phoneNumberController = TextEditingController(text: widget.currentPhoneNumber);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // Validasi form kosong
    if (_fullNameController.text.trim().isEmpty || 
        _usernameController.text.trim().isEmpty || 
        _phoneNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua kolom harus diisi!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Mendapatkan UID User yang sedang login
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Update data ke Firebase Realtime Database
        await FirebaseDatabase.instance.ref('users/${currentUser.uid}').update({
          'fullName': _fullNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
        });

        if (mounted) {
          Navigator.pop(context, true); // Kembali dan kirim sinyal 'true' (sukses)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: $e'),
            backgroundColor: Colors.red,
          ),
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
        title: const Text('Edit Profil', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE6E6FA),
                        child: Icon(Icons.person, size: 50, color: Color(0xFF1E1E96)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fitur ubah foto akan segera hadir!')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E1E96),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildLabel('Nama Lengkap'),
                _buildTextField(_fullNameController, 'Masukkan nama lengkap', Icons.person_outline),
                const SizedBox(height: 16),
                
                _buildLabel('Username'),
                _buildTextField(_usernameController, 'Masukkan username', Icons.alternate_email),
                const SizedBox(height: 16),
                
                _buildLabel('Nomor Telepon'),
                _buildTextField(
                  _phoneNumberController, 
                  'Masukkan nomor telepon', 
                  Icons.phone_outlined, 
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E96),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text(
                            'Simpan Perubahan', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF1E1E96)),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
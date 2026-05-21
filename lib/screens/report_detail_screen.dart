import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_report_screen.dart'; 

class ReportDetailScreen extends StatefulWidget {
  final String docId;

  const ReportDetailScreen({Key? key, required this.docId}) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // Ambil user ID yang sedang login secara dinamis
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  // --- FUNGSI BUKA PETA YANG SUDAH DIPERBARUI (MENDUKUNG SEMUA FORMAT) ---
  Future<void> _openMapApp(String query) async {
    // 1. Jika user menginput link berawalan http atau https langsung buka browsernya
    if (query.startsWith('http')) {
      final Uri uri = Uri.parse(query);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 2. Jika input berupa Alamat, Koordinat Desimal, atau Koordinat Derajat (DMS)
    // Kita ubah teksnya menjadi format pencarian URL yang aman (URL Encode)
    final String encodedQuery = Uri.encodeComponent(query);
    
    // Default format untuk Android (menggunakan query pencarian)
    String url = "geo:0,0?q=$encodedQuery"; 
    
    // Jika perangkat adalah iOS, gunakan format Apple Maps
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      url = "maps://?q=$encodedQuery";
    }

    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        // Coba buka aplikasi peta bawaan HP (Google Maps / Apple Maps)
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // BACKUP: Jika di HP tidak ada aplikasi peta, buka lewat website Google Maps
        final Uri fallbackUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedQuery");
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka peta: $e'))
      );
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Baru saja';
    final DateTime now = DateTime.now();
    final DateTime reportedTime = timestamp.toDate();
    final Duration diff = now.difference(reportedTime);

    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').doc(widget.docId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Data laporan tidak ditemukan.'));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          String category = data['category'] ?? 'Umum';
          String urgency = data['urgency'] ?? 'RENDAH';
          String title = data['title'] ?? 'Tanpa Judul';
          String location = data['location'] ?? 'Lokasi tidak diketahui';
          String description = data['description'] ?? 'Tidak ada deskripsi.';
          int upvotes = data['upvotes'] ?? 0;
          String status = data['status'] ?? 'Aktif';
          String reporterId = data['reporterId'] ?? '';
          
          String? imageUrl = data['imageUrl'];
          String reporterName = data['reporterName'] ?? 'Anonim';
          Timestamp? timestamp = data['timestamp'] as Timestamp?;
          String timeAgo = _getTimeAgo(timestamp);

          List<dynamic> supportedBy = data['supportedBy'] ?? [];
          bool isSupportedByMe = supportedBy.contains(currentUserId);
          
          // Mengambil teks dari koordinat, atau gunakan alamat jika kosong
          String coordinates = data['coordinates'] ?? location; 
          
          // Cek apakah laporan ini milik user yang sedang login
          bool isMyReport = currentUserId == reporterId;

          return SafeArea(
            child: Column(
              children: [
                _buildHeader(context, category, urgency, title, location, isMyReport, description),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          _buildPhotoCard(imageUrl),
                          const SizedBox(height: 16),
                        ],
                        
                        _buildStatusCard(reporterName, timeAgo, status),
                        const SizedBox(height: 16),
                        _buildDescriptionCard(description),
                        const SizedBox(height: 16),
                        _buildCoordinatesCard(coordinates),
                        const SizedBox(height: 16),
                        _buildSupportCard(upvotes),
                        const SizedBox(height: 24),
                        _buildBottomActions(upvotes, isSupportedByMe),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String category, String urgency, String title, String location, bool isMyReport, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1E1E96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              // TOMBOL EDIT MUNCUL JIKA INI LAPORAN SAYA
              if (isMyReport)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditReportScreen(
                          docId: widget.docId,
                          initialTitle: title,
                          initialDesc: desc,
                          initialLocation: location,
                          initialUrgency: urgency,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(category, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgency.toUpperCase() == 'DARURAT' ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(urgency.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(location, style: const TextStyle(color: Colors.white70, fontSize: 14))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
    );
  }

  Widget _buildStatusCard(String reporterName, String timeAgo, String status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatusItem('Status', status, isStatus: true),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatusItem('Dilaporkan', timeAgo),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatusItem('Pelapor', reporterName),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, {bool isStatus = false}) {
    Color statusColor = Colors.red;
    if (value.toLowerCase() == 'ditangani') statusColor = Colors.teal;
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            if (isStatus) Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isStatus ? statusColor : Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(String description) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: Colors.black87, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatesCard(String coordinates) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openMapApp(coordinates),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lokasi / Koordinat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE6E6FA), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.near_me, color: Color(0xFF2A23C2), size: 18),
                    const SizedBox(width: 8),
                    // Dibungkus Expanded agar url yang kepanjangan tidak melebihi layar
                    Expanded(
                      child: Text(
                        coordinates, 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Buka Peta', style: TextStyle(fontSize: 10, color: Color(0xFF2A23C2), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard(int upvotes) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dukungan Warga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Laporan ini mendapat dukungan dari $upvotes warga.', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(int upvotes, bool isSupportedByMe) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              var docRef = FirebaseFirestore.instance.collection('reports').doc(widget.docId);
              if (isSupportedByMe) {
                docRef.update({'upvotes': FieldValue.increment(-1), 'supportedBy': FieldValue.arrayRemove([currentUserId])});
              } else {
                docRef.update({'upvotes': FieldValue.increment(1), 'supportedBy': FieldValue.arrayUnion([currentUserId])});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E96), padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(isSupportedByMe ? 'Batalkan ($upvotes)' : 'Dukung ($upvotes)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportDetailScreen extends StatefulWidget {
  final String docId;

  const ReportDetailScreen({Key? key, required this.docId}) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // Simulasi ID User (Nanti diganti dengan FirebaseAuth.instance.currentUser!.uid)
  final String currentUserId = "user_123";

  // Fungsi untuk mengubah Timestamp menjadi teks "waktu berlalu" (contoh: "2 jam lalu")
  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Baru saja';
    final DateTime now = DateTime.now();
    final DateTime reportedTime = timestamp.toDate();
    final Duration diff = now.difference(reportedTime);

    if (diff.inDays > 0) {
      return '${diff.inDays} hari lalu';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} jam lalu';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
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
          
          // Mengambil foto, nama pelapor, dan waktu dari Firestore
          String? imageUrl = data['imageUrl'];
          String reporterName = data['reporterName'] ?? 'Anonim';
          Timestamp? timestamp = data['timestamp'] as Timestamp?;
          String timeAgo = _getTimeAgo(timestamp);

          // Cek dukungan
          List<dynamic> supportedBy = data['supportedBy'] ?? [];
          bool isSupportedByMe = supportedBy.contains(currentUserId);
          
          String coordinates = data['coordinates'] ?? '-6.229700, 106.829500';

          return SafeArea(
            child: Column(
              children: [
                _buildHeader(context, category, urgency, title, location),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Menampilkan foto jika ada URL gambar dari Firestore
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          _buildPhotoCard(imageUrl),
                          const SizedBox(height: 16),
                        ],
                        
                        // Melempar nama dinamis, waktu dinamis, dan status
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

  Widget _buildHeader(BuildContext context, String category, String urgency, String title, String location) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1E1E96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      category,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgency.toUpperCase() == 'DARURAT' ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  urgency.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET UNTUK MENAMPILKAN FOTO ---
  Widget _buildPhotoCard(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey.shade300,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
            ),
          );
        },
      ),
    );
  }

  // Card status sekarang menerima variabel dinamis
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
            _buildStatusItem('Dilaporkan', timeAgo), // Waktu dinamis
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatusItem('Pelapor', reporterName), // Nama dinamis
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, {bool isStatus = false}) {
    // Menyesuaikan warna indikator berdasarkan teks status
    Color statusColor = Colors.red;
    if (value.toLowerCase() == 'ditangani') statusColor = Colors.teal;
    if (value.toLowerCase() == 'sedang proses') statusColor = Colors.orange;

    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isStatus) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isStatus ? statusColor : Colors.black87,
              ),
            ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Koordinat Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6E6FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.near_me, color: Color(0xFF2A23C2), size: 18),
                  const SizedBox(width: 8),
                  Text(coordinates, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(int upvotes) {
    int target = 50;
    double progress = (upvotes / target).clamp(0.0, 1.0);

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
            Text(
              'Laporan ini mendapat dukungan dari $upvotes warga. Semakin banyak dukungan, semakin cepat ditangani.',
              style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2A23C2)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Target $target dukungan', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                docRef.update({
                  'upvotes': FieldValue.increment(-1),
                  'supportedBy': FieldValue.arrayRemove([currentUserId])
                });
              } else {
                docRef.update({
                  'upvotes': FieldValue.increment(1),
                  'supportedBy': FieldValue.arrayUnion([currentUserId])
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E96), 
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  isSupportedByMe ? 'Batalkan ($upvotes)' : 'Dukung ($upvotes)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 54, 
          width: 54,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share_outlined, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
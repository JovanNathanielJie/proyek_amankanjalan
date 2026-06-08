import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
// Tambahan Import untuk Mini Map
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'edit_report_screen.dart'; 

class ReportDetailScreen extends StatefulWidget {
  final String docId;

  const ReportDetailScreen({Key? key, required this.docId}) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  Future<void> _openMapApp(String query) async {
    if (query.startsWith('http')) {
      final Uri uri = Uri.parse(query);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final String encodedQuery = Uri.encodeComponent(query);
    String url = "geo:0,0?q=$encodedQuery"; 
    
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      url = "maps://?q=$encodedQuery";
    }

    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final Uri fallbackUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedQuery");
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka peta: $e'))
        );
      }
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

  // Helper untuk mengubah string "lat,lng" dari database menjadi LatLng
  LatLng? _parseCoordinates(String coords) {
    try {
      final parts = coords.split(',');
      if (parts.length >= 2) {
        double lat = double.parse(parts[0].trim());
        double lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      return null; // Gagal parse, kembalikan null
    }
    return null;
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
          
          String coordinates = data['coordinates'] ?? ''; 
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
                        
                        // Pass location (Alamat) dan coordinates (Koordinat murni)
                        _buildMapAndLocationCard(location, coordinates),
                        
                        const SizedBox(height: 16),
                        _buildSupportCard(upvotes),
                        const SizedBox(height: 24),
                        _buildBottomActions(upvotes, isSupportedByMe, title, category, urgency, location, description, isMyReport, reporterId),
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

  // KARTU LOKASI BARU YANG MENAMPILKAN MINI MAP & ALAMAT
  Widget _buildMapAndLocationCard(String locationText, String coordinatesStr) {
    // Coba konversi string ke titik LatLng
    LatLng? point = _parseCoordinates(coordinatesStr);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Titik Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            // 1. TAMPILKAN MINI MAP JIKA KOORDINAT VALID
            if (point != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: IgnorePointer( // Mematikan scroll map agar tidak bentrok dengan scroll halaman
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.amankanjalan.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
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
              ),
              const SizedBox(height: 12),
            ],

            // 2. TAMPILKAN TEKS ALAMAT MANUSIA
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2A23C2), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationText,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. TOMBOL BUKA GOOGLE MAPS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Prioritaskan koordinat jika ada, kalau kosong pakai teks alamat
                  String searchQuery = coordinatesStr.isNotEmpty ? coordinatesStr : locationText;
                  _openMapApp(searchQuery);
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Buka di Aplikasi Peta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E1E96),
                  side: const BorderSide(color: Color(0xFF1E1E96)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(int upvotes) {
    final int targetSupport = 50; 
    final double progress = upvotes >= targetSupport ? 1.0 : upvotes / targetSupport;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dukungan Warga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : const Color(0xFF2A23C2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$upvotes warga mendukung', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF2A23C2), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Target $targetSupport dukungan', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(int upvotes, bool isSupportedByMe, String title, String category, String urgency, String location, String description, bool isMyReport, String reporterId) {
    return Column(
      children: [
        Row(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E96),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isSupportedByMe ? 'Batalkan Dukungan' : 'Dukung', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _shareReport(title, category, urgency, location, description),
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                label: const Text('Bagikan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E96),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        if (isMyReport)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteConfirmationDialog(),
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: const Text('Hapus Laporan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _shareReport(String title, String category, String urgency, String location, String description) async {
    final String shareMessage = '''🚨 Laporan AmankanJalan

📍 Judul: $title
🏷️ Kategori: $category
⚠️ Urgensi: $urgency
📌 Lokasi: $location

📝 Deskripsi:
$description

Bagikan informasi ini untuk meningkatkan kesadaran keselamatan jalan bersama!''';

    try {
      await Share.share(shareMessage, subject: 'Laporan AmankanJalan: $title');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Laporan?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Apakah Anda yakin ingin menghapus laporan ini? Tindakan ini tidak dapat dibatalkan.', style: TextStyle(color: Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteReport();
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menghapus laporan...'), duration: Duration(seconds: 2)),
      );

      final doc = await FirebaseFirestore.instance.collection('reports').doc(widget.docId).get();
      final reporterId = doc['reporterId'] ?? '';

      if (reporterId != currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Anda tidak berhak menghapus laporan ini!'), backgroundColor: Colors.red));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('reports').doc(widget.docId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Laporan berhasil dihapus'), backgroundColor: Colors.green));
        Future.delayed(const Duration(milliseconds: 500), () => Navigator.pop(context));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Gagal menghapus laporan: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
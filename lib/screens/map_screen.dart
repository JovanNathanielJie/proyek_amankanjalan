import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header
            _buildHeader(),
            
            // 2. Simulasi Peta Interaktif (Sesuai Gambar Laporan)
            _buildMapSimulation(),

            // 3. Daftar Lokasi Laporan (Real-time dari Firestore)
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Lokasi Laporan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildReportList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- KOMPONEN HEADER ---
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E96),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Peta Laporan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Sebaran masalah jalan di sekitar Anda',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --- KOMPONEN SIMULASI PETA (MOCKUP VISUAL) ---
  Widget _buildMapSimulation() {
    return Container(
      height: 220,
      width: double.infinity,
      color: const Color(0xFF1A1A2E), // Warna latar belakang peta mode gelap
      child: Stack(
        children: [
          // Garis-garis peta (grid dummy)
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),
          
          // Teks Info Area di Kiri Atas
          Positioned(
            top: 12,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Tampilan Peta',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  'Palembang & Sekitarnya',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),

          // Titik-titik Laporan (Markers Dummy)
          _buildMapMarker(top: 60, left: 50, urgency: 'Darurat'),
          _buildMapMarker(top: 100, left: 120, urgency: 'Sedang'),
          _buildMapMarker(top: 40, left: 200, urgency: 'Rendah'),
          _buildMapMarker(top: 130, left: 280, urgency: 'Darurat'),
          _buildMapMarker(top: 150, left: 180, urgency: 'Sedang'),

          // Legenda Urgensi di Kanan Bawah
          Positioned(
            bottom: 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Darurat', Colors.red),
                  const SizedBox(height: 4),
                  _buildLegendItem('Sedang', Colors.orange),
                  const SizedBox(height: 4),
                  _buildLegendItem('Rendah', Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker({required double top, required double left, required String urgency}) {
    Color markerColor = Colors.green;
    if (urgency == 'Darurat') markerColor = Colors.red;
    if (urgency == 'Sedang') markerColor = Colors.orange;

    return Positioned(
      top: top,
      left: left,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: markerColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  // --- KOMPONEN DAFTAR LAPORAN (LIST VIEW) ---
  Widget _buildReportList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada laporan di area ini.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            
            String title = data['title'] ?? 'Tanpa Judul';
            String location = data['location'] ?? 'Lokasi tidak diketahui';
            String category = data['category'] ?? 'Umum';
            int upvotes = data['upvotes'] ?? 0;
            String urgency = data['urgency'] ?? 'RENDAH';

            // Menentukan Ikon dan Warna Kategori
            IconData catIcon = Icons.warning_amber_rounded;
            Color catBgColor = Colors.orange.shade100;
            Color catIconColor = Colors.orange;

            if (category == 'Lampu Mati') {
              catIcon = Icons.lightbulb_outline;
              catBgColor = Colors.orange.shade100;
              catIconColor = Colors.orange;
            } else if (category == 'Rawan Kecelakaan') {
              catIcon = Icons.warning_amber_rounded;
              catBgColor = Colors.red.shade100;
              catIconColor = Colors.red;
            } else if (category == 'Area Gelap') {
              catIcon = Icons.dark_mode_outlined;
              catBgColor = Colors.purple.shade100;
              catIconColor = Colors.purple;
            }

            // Menentukan Warna Upvote Badge berdasarkan Urgensi
            Color urgencyColor = Colors.green;
            if (urgency.toUpperCase() == 'DARURAT') urgencyColor = Colors.red;
            if (urgency.toUpperCase() == 'SEDANG') urgencyColor = Colors.orange;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: catBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(catIcon, color: catIconColor, size: 20),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                location,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_upward, color: urgencyColor, size: 14),
                  const SizedBox(height: 2),
                  Text(
                    '$upvotes',
                    style: TextStyle(
                      color: urgencyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Class khusus untuk menggambar grid garis pada background peta tiruan
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
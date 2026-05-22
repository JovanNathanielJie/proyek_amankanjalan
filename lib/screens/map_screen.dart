import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart'; // Package peta asli
import 'package:latlong2/latlong.dart'; // Package koordinat peta
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  
  // Koordinat default (Pusat Kota Palembang) jika tidak ada laporan
  final LatLng _palembangCenter = const LatLng(-2.990934, 104.756554);

  // Fungsi untuk membuka peta eksternal (Google Maps/Apple Maps) saat list diklik
  Future<void> _openExternalMap(String query) async {
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

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedQuery"), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka peta: $e')));
    }
  }

  // Fungsi pintar untuk mengekstrak format Desimal (-6.22, 106.82)
  LatLng? _parseCoordinates(String coords) {
    try {
      final parts = coords.split(',');
      if (parts.length == 2) {
        double lat = double.parse(parts[0].trim());
        double lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      // Jika formatnya link URL atau teks sembarangan, abaikan (return null)
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        // Kita bungkus SELURUH halaman dengan StreamBuilder 
        // agar Peta dan List berbagi data yang sama dari Firestore
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            
            bool isLoading = snapshot.connectionState == ConnectionState.waiting;
            List<QueryDocumentSnapshot> docs = snapshot.hasData ? snapshot.data!.docs : [];

            // Membangun daftar titik (markers) untuk peta
            List<Marker> mapMarkers = [];
            
            if (!isLoading) {
              for (var doc in docs) {
                var data = doc.data() as Map<String, dynamic>;
                String coordsStr = data['coordinates'] ?? '';
                String urgency = data['urgency'] ?? 'RENDAH';
                String title = data['title'] ?? 'Laporan';

                // Tentukan warna pin
                Color markerColor = Colors.green;
                if (urgency.toUpperCase() == 'DARURAT') markerColor = Colors.red;
                if (urgency.toUpperCase() == 'SEDANG') markerColor = Colors.orange;

                // Coba konversi teks ke koordinat peta
                LatLng? position = _parseCoordinates(coordsStr);

                if (position != null) {
                  mapMarkers.add(
                    Marker(
                      point: position,
                      width: 60,
                      height: 70,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(title), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: _buildCustomMarker(markerColor, urgency, title),
                      ),
                    ),
                  );
                }
              }
            }

            return Column(
              children: [
                _buildHeader(),
                _buildLegend(),
                
                // --- PETA ASLI ---
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: mapMarkers.isNotEmpty ? mapMarkers.first.point : _palembangCenter,
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.amankanjalan.app',
                          ),
                          MarkerLayer(
                            markers: mapMarkers,
                          ),
                        ],
                      ),
                ),

                // --- DAFTAR LAPORAN ---
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : docs.isEmpty
                                ? const Center(child: Text('Belum ada laporan di area ini.', style: TextStyle(color: Colors.grey)))
                                : ListView.separated(
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
                                      // Ambil data koordinat atau link untuk dibuka
                                      String tapData = data['coordinates'] ?? location;

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

                                      Color urgencyColor = Colors.green;
                                      if (urgency.toUpperCase() == 'DARURAT') urgencyColor = Colors.red;
                                      if (urgency.toUpperCase() == 'SEDANG') urgencyColor = Colors.orange;

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: catBgColor, borderRadius: BorderRadius.circular(10)),
                                          child: Icon(catIcon, color: catIconColor, size: 20),
                                        ),
                                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        subtitle: Text(location, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Tombol Bagikan
                                            IconButton(
                                              icon: const Icon(Icons.share_outlined, size: 18),
                                              onPressed: () => _shareReport(title, category, urgency, location),
                                              tooltip: 'Bagikan',
                                            ),
                                            // Upvote
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.arrow_upward, color: urgencyColor, size: 14),
                                                const SizedBox(height: 2),
                                                Text('$upvotes', style: TextStyle(color: urgencyColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        onTap: () => _openExternalMap(tapData),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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
          Text('Peta Laporan', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Sebaran masalah jalan di sekitar Anda', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  /// Widget untuk menampilkan legenda urgensi
  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tingkat Urgensi',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Darurat - Merah
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.priority_high, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Darurat', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              // Sedang - Oranye
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Sedang', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              // Rendah - Hijau
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Rendah', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget untuk custom marker sesuai tingkat urgensi
  Widget _buildCustomMarker(Color color, String urgency, String title) {
    IconData icon = Icons.location_on;
    
    // Tentukan icon berdasarkan urgensi
    if (urgency.toUpperCase() == 'DARURAT') {
      icon = Icons.priority_high; // Tanda seru
    } else if (urgency.toUpperCase() == 'SEDANG') {
      icon = Icons.remove; // Garis/strip
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow background layer
        Positioned(
          top: 8,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        // Main marker circle
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 26, weight: 700),
          ),
        ),
        // Pointer ke bawah
        Positioned(
          top: 32,
          child: CustomPaint(
            painter: _TrianglePainter(color),
            size: const Size(24, 12),
          ),
        ),
      ],
    );
  }

  /// Fungsi untuk membagikan laporan
  Future<void> _shareReport(String title, String category, String urgency, String location) async {
    final String shareMessage = '''🚨 Laporan AmankanJalan

📍 Judul: $title
🏷️ Kategori: $category
⚠️ Urgensi: $urgency
📌 Lokasi: $location

Bagikan informasi ini untuk meningkatkan kesadaran keselamatan jalan bersama!''';

    try {
      await Share.share(
        shareMessage,
        subject: 'Laporan AmankanJalan: $title',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membagikan: $e')),
      );
    }
  }
}

/// Custom painter untuk menggambar segitiga pointer
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Buat segitiga dengan path
    ui.Path path = ui.Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => color != oldDelegate.color;
}

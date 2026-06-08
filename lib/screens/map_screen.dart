import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Koordinat default (Pusat Kota Palembang)
  final LatLng _palembangCenter = const LatLng(-2.990934, 104.756554);
  final MapController _mapController = MapController();
  
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _centerToUserLocation(); // Coba pusatkan ke pengguna saat pertama dibuka
  }

  // --- FUNGSI MENGAMBIL LOKASI PENGGUNA (GPS) ---
  Future<void> _centerToUserLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng userLoc = LatLng(position.latitude, position.longitude);
      
      // Geser peta ke lokasi pengguna
      _mapController.move(userLoc, 13.0);
    } catch (e) {
      // Abaikan jika gagal, peta tetap di Palembang
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // --- FUNGSI PINTAR UNTUK MEMBACA KOORDINAT DARI FIRESTORE ---
  LatLng? _parseCoordinates(String coords) {
    if (coords.trim().isEmpty) return null;
    try {
      // Pisahkan teks "-2.99,104.75" berdasarkan koma
      final parts = coords.split(',');
      if (parts.length >= 2) {
        double lat = double.parse(parts[0].trim());
        double lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // Fungsi untuk membuka aplikasi Google Maps
  Future<void> _openExternalMap(String query) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka peta: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        // StreamBuilder memantau database Firestore secara Real-Time
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            
            bool isLoading = snapshot.connectionState == ConnectionState.waiting;
            List<QueryDocumentSnapshot> docs = snapshot.hasData ? snapshot.data!.docs : [];

            // Membangun daftar pin marker untuk peta
            List<Marker> mapMarkers = [];
            
            if (!isLoading) {
              for (var doc in docs) {
                var data = doc.data() as Map<String, dynamic>;
                String coordsStr = data['coordinates'] ?? '';
                String urgency = data['urgency'] ?? 'RENDAH';
                String category = data['category'] ?? 'Umum';
                String title = data['title'] ?? 'Laporan';

                // Tentukan warna pin berdasarkan urgensi
                Color markerColor = Colors.green;
                if (urgency.toUpperCase() == 'DARURAT') markerColor = Colors.red;
                if (urgency.toUpperCase() == 'SEDANG') markerColor = Colors.orange;

                // Konversi teks database ("-2.9,104.7") menjadi LatLng
                LatLng? position = _parseCoordinates(coordsStr);

                if (position != null) {
                  mapMarkers.add(
                    Marker(
                      point: position,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          // Jika pin di peta diklik, munculkan pop-up kecil
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), 
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1E1E96),
                            ),
                          );
                        },
                        child: _buildCustomMarker(markerColor, urgency, category),
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
                
                // --- PETA UTAMA ---
                SizedBox(
                  height: 300, // Diperbesar sedikit agar lebih jelas
                  width: double.infinity,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _palembangCenter,
                          initialZoom: 13.0,
                          minZoom: 5.0,
                          maxZoom: 18.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.amankanjalan.app',
                          ),
                          // Masukkan semua marker yang berhasil diparsing
                          MarkerLayer(markers: mapMarkers),
                        ],
                      ),
                      
                      // Tombol melayang untuk kembali ke lokasi saya
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: _centerToUserLocation,
                          child: _isGettingLocation 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, color: Color(0xFF1E1E96)),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- DAFTAR LAPORAN (LIST VIEW) ---
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
                                ? const Center(child: Text('Belum ada laporan.', style: TextStyle(color: Colors.grey)))
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
                                      
                                      // Data untuk dibuka di peta
                                      String coordsData = data['coordinates'] ?? location;

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
                                            IconButton(
                                              icon: const Icon(Icons.share_outlined, size: 18),
                                              onPressed: () => _shareReport(title, category, urgency, location),
                                              tooltip: 'Bagikan',
                                            ),
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
                                        // Jika ditekan, buka koordinat tersebut ke Google Maps
                                        onTap: () => _openExternalMap(coordsData),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.priority_high, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Darurat', style: TextStyle(fontSize: 11, color: Colors.grey))),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.remove, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Sedang', style: TextStyle(fontSize: 11, color: Colors.grey))),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Rendah', style: TextStyle(fontSize: 11, color: Colors.grey))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Desain Marker Kustom (Pin Point) yang ada di Peta
  Widget _buildCustomMarker(Color color, String urgency, String category) {
    IconData icon = Icons.location_on;

    final cat = category.toLowerCase();
    if (cat.contains('lampu')) {
      icon = Icons.lightbulb;
    } else if (cat.contains('banjir') || cat.contains('air')) {
      icon = Icons.water_drop;
    } else if (cat.contains('rawan') || cat.contains('kecelakaan')) {
      icon = Icons.warning_amber_rounded;
    } else if (cat.contains('gelap')) {
      icon = Icons.dark_mode;
    }

    if (urgency.toUpperCase() == 'DARURAT') {
      icon = Icons.priority_high; 
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
        // Segitiga penunjuk ke bawah
        CustomPaint(
          painter: _TrianglePainter(color),
          size: const Size(12, 8),
        ),
      ],
    );
  }

  Future<void> _shareReport(String title, String category, String urgency, String location) async {
    final String shareMessage = '''🚨 Laporan AmankanJalan

📍 Judul: $title
🏷️ Kategori: $category
⚠️ Urgensi: $urgency
📌 Lokasi: $location

Bagikan informasi ini untuk meningkatkan kesadaran keselamatan jalan bersama!''';

    try {
      await Share.share(shareMessage, subject: 'Laporan AmankanJalan: $title');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
      }
    }
  }
}

// Pelukis Segitiga Menghadap Bawah (Untuk Ujung Pin Peta)
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    ui.Path path = ui.Path();
    path.moveTo(0, 0); // Kiri Atas
    path.lineTo(size.width, 0); // Kanan Atas
    path.lineTo(size.width / 2, size.height); // Ujung bawah tengah
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => color != oldDelegate.color;
}
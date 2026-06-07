import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka peta: $e')));
      }
    }
  }

  // Fungsi pintar untuk mengekstrak format Desimal (-6.22, 106.82)
  LatLng? _parseCoordinates(String coords) {
    if (coords.isEmpty) return null;
    
    try {
      // Coba format desimal sederhana terlebih dahulu
      final simpleParts = coords.split(RegExp(r'[;,]'));
      if (simpleParts.length >= 2) {
        try {
          double lat = double.parse(simpleParts[0].replaceAll(RegExp('[^0-9+\-\.]'), '').trim());
          double lng = double.parse(simpleParts[1].replaceAll(RegExp('[^0-9+\-\.]'), '').trim());
          if (lat.abs() <= 90 && lng.abs() <= 180) return LatLng(lat, lng);
        } catch (_) {
          // lanjut ke parser DMS
        }
      }

      // Jika ada simbol derajat atau huruf NSEW, coba parse DMS (contoh: 2°57'37.5"S 104°44'16.4"E)
      if (coords.contains('°') || RegExp(r'[NSEWnsew]').hasMatch(coords)) {
        // Pisahkan dua komponen (lat, lon) berdasarkan huruf arah atau koma
        // Cobalah split dengan ruang yang memisahkan dua bagian
        List<String> parts = [];
        // Jika ada koma/titik koma gunakan itu
        if (coords.contains(',')) {
          parts = coords.split(',');
        } else {
          // Split by patterns that separate lat and lon (mis. "S " sebelum lon)
          final match = RegExp(r'([NS].*?)[,\s]+([EW].*)', caseSensitive: false).firstMatch(coords);
          if (match != null && match.groupCount >= 2) {
            parts = [match.group(1)!, match.group(2)!];
          } else {
            // Fall back: split by whitespace into two halves
            final tokens = coords.trim().split(RegExp(r'\s+'));
            if (tokens.length >= 2) {
              final half = (tokens.length / 2).ceil();
              parts = [tokens.sublist(0, half).join(' '), tokens.sublist(half).join(' ')];
            }
          }
        }

        if (parts.length >= 2) {
          double? lat = _dmsToDecimal(parts[0]);
          double? lng = _dmsToDecimal(parts[1]);
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    } catch (e) {
      // Koordinat tidak valid
    }
    return null;
  }

  // Cache untuk hasil geocoding alamat agar tidak memanggil ulang API berulang
  final Map<String, LatLng> _geocodeCache = {};
  final Set<String> _geocodingInProgress = {};

  Future<void> _geocodeAndCache(String docId, String address) async {
    if (address.trim().isEmpty) return;
    if (_geocodeCache.containsKey(docId) || _geocodingInProgress.contains(docId)) return;
    _geocodingInProgress.add(docId);
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        _geocodeCache[docId] = LatLng(loc.latitude, loc.longitude);
        if (mounted) setState(() {});
      }
    } catch (e) {
      // ignore geocoding errors silently
    } finally {
      _geocodingInProgress.remove(docId);
    }
  }

  double? _dmsToDecimal(String part) {
    try {
      String p = part.trim();
      // Ambil arah jika ada
      String dir = '';
      final dirMatch = RegExp(r'([NSEWnsew])').firstMatch(p);
      if (dirMatch != null) {
        dir = dirMatch.group(1)!.toUpperCase();
      }

      // Hapus karakter yang bukan angka, tanda minus, titik, derajat, menit, detik, atau spasi
      p = p.replaceAll('\u00B0', '°');

      // Pattern DMS: 12°34'56.7"S  or 12 34 56 S
        final dmsMatch = RegExp(r'''(\d+(?:\.\d+)?)\s*[°\s]\s*(\d+(?:\.\d+)?)?\s*['\s]?\s*(\d+(?:\.\d+)?)?\s*"?\s*([NSEWnsew])?''',
            caseSensitive: false)
          .firstMatch(p);

      if (dmsMatch != null) {
        final deg = double.parse(dmsMatch.group(1)!);
        final min = dmsMatch.group(2) != null && dmsMatch.group(2)!.isNotEmpty ? double.parse(dmsMatch.group(2)!) : 0.0;
        final sec = dmsMatch.group(3) != null && dmsMatch.group(3)!.isNotEmpty ? double.parse(dmsMatch.group(3)!) : 0.0;
        final direction = (dmsMatch.group(4) ?? dir).toUpperCase();

        double dec = deg + (min / 60.0) + (sec / 3600.0);
        if (direction == 'S' || direction == 'W') dec = -dec;
        return dec;
      }

      // Jika tidak cocok DMS, coba parse langsung angka yang ada
      final numMatch = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(p);
      if (numMatch != null) return double.parse(numMatch.group(0)!);
    } catch (_) {}
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
                String locationText = data['location'] ?? '';
                String urgency = data['urgency'] ?? 'RENDAH';
                String category = data['category'] ?? 'Umum';
                String title = data['title'] ?? 'Laporan';

                // Tentukan warna pin
                Color markerColor = Colors.green;
                if (urgency.toUpperCase() == 'DARURAT') markerColor = Colors.red;
                if (urgency.toUpperCase() == 'SEDANG') markerColor = Colors.orange;

                // Coba konversi teks ke koordinat peta dari field 'coordinates'
                LatLng? position = _parseCoordinates(coordsStr);

                // Jika tidak ada coordinates tetapi ada lokasi, coba gunakan cache geocoding
                if (position == null && locationText.isNotEmpty) {
                  if (_geocodeCache.containsKey(doc.id)) {
                    position = _geocodeCache[doc.id];
                  } else {
                    // Mulai proses geocoding secara async (akan memicu setState ketika selesai)
                    _geocodeAndCache(doc.id, locationText);
                  }
                }

                if (position != null) {
                  mapMarkers.add(
                      Marker(
                        point: position,
                        width: 44,
                        height: 56,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(title), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: _buildCustomMarker(markerColor, urgency, title, category),
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
                          initialCenter: mapMarkers.isNotEmpty 
                            ? mapMarkers.first.point 
                            : _palembangCenter,
                          initialZoom: 13.0,
                          minZoom: 5.0,
                          maxZoom: 18.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.amankanjalan.app',
                            maxZoom: 19,
                          ),
                          if (mapMarkers.isNotEmpty)
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
  Widget _buildCustomMarker(Color color, String urgency, String title, String category) {
    IconData icon = Icons.location_on;

    // Tentukan icon berdasarkan kategori jika tersedia
    final cat = category.toLowerCase();
    if (cat.contains('lampu') || cat.contains('lampu mati')) {
      icon = Icons.lightbulb;
    } else if (cat.contains('banjir') || cat.contains('air')) {
      icon = Icons.water_drop;
    } else if (cat.contains('rawan') || cat.contains('kecelakaan')) {
      icon = Icons.warning_amber_rounded;
    } else if (cat.contains('gelap')) {
      icon = Icons.dark_mode;
    } else if (cat.contains('jalan') && cat.contains('berlobang')) {
      icon = Icons.report; // fallback for pothole-like issues
    }

    // Override icon for urgency levels when appropriate
    if (urgency.toUpperCase() == 'DARURAT') {
      icon = Icons.priority_high; // Tanda seru
    } else if (urgency.toUpperCase() == 'SEDANG') {
      // keep category icon but you could optionally change it
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Subtle glow (smaller)
        Positioned(
          top: 6,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        // Main marker circle (smaller)
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
        // Small pointer
        Positioned(
          top: 28,
          child: CustomPaint(
            painter: _TrianglePainter(color),
            size: const Size(18, 9),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan: $e')),
        );
      }
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart'; // Package peta asli
import 'package:latlong2/latlong.dart'; // Package koordinat peta

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
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(title), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: Icon(
                          Icons.location_on,
                          color: markerColor,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                }
              }
            }

            return Column(
              children: [
                _buildHeader(),
                
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
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.arrow_upward, color: urgencyColor, size: 14),
                                            const SizedBox(height: 2),
                                            Text('$upvotes', style: TextStyle(color: urgencyColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
}
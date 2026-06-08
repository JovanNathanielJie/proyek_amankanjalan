import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng _palembangCenter = const LatLng(-2.990934, 104.756554);
  final LatLngBounds _palembangBounds = LatLngBounds(
    const LatLng(-3.36, 104.54),
    const LatLng(-2.82, 104.92),
  );
  final MapController _mapController = MapController();

  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _centerToUserLocation();
  }

  Future<void> _centerToUserLocation() async {
    if (mounted) {
      setState(() => _isGettingLocation = true);
    }

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final LatLng userLoc = LatLng(position.latitude, position.longitude);

      _mapController.move(
        _isWithinPalembangBounds(userLoc) ? userLoc : _palembangCenter,
        13.0,
      );
    } catch (_) {
      _mapController.move(_palembangCenter, 13.0);
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  bool _isWithinPalembangBounds(LatLng point) {
    return point.latitude >= _palembangBounds.southWest.latitude &&
        point.latitude <= _palembangBounds.northEast.latitude &&
        point.longitude >= _palembangBounds.southWest.longitude &&
        point.longitude <= _palembangBounds.northEast.longitude;
  }

  LatLng? _parseCoordinates(String coords) {
    if (coords.trim().isEmpty) return null;
    try {
      final parts = coords.split(',');
      if (parts.length >= 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openExternalMap(String query) async {
    final String encodedQuery = Uri.encodeComponent(query);
    String url = 'geo:0,0?q=$encodedQuery';

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      url = 'maps://?q=$encodedQuery';
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
          ),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka peta: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapHeight = (constraints.maxHeight * 0.32).clamp(200.0, 280.0);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
                final List<QueryDocumentSnapshot> docs = snapshot.hasData ? snapshot.data!.docs : [];

                final List<Marker> mapMarkers = [];
                if (!isLoading) {
                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String coordsStr = data['coordinates'] ?? '';
                    final String urgency = data['urgency'] ?? 'RENDAH';
                    final String category = data['category'] ?? 'Umum';
                    final String title = data['title'] ?? 'Laporan';

                    Color markerColor = Colors.green;
                    if (urgency.toUpperCase() == 'DARURAT') {
                      markerColor = Colors.red;
                    } else if (urgency.toUpperCase() == 'SEDANG') {
                      markerColor = Colors.orange;
                    }

                    final position = _parseCoordinates(coordsStr);
                    if (position != null && _isWithinPalembangBounds(position)) {
                      mapMarkers.add(
                        Marker(
                          point: position,
                          width: 50,
                          height: 50,
                          child: GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(title),
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

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      _buildLegend(),
                      SizedBox(
                        height: mapHeight,
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
                                MarkerLayer(markers: mapMarkers),
                              ],
                            ),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton(
                                heroTag: "map_location_btn", // <-- INI SOLUSI ANTI FREEZE
                                mini: true,
                                backgroundColor: Colors.white,
                                onPressed: _centerToUserLocation,
                                child: _isGettingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location, color: Color(0xFF1E1E96)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
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
                            if (isLoading)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (docs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'Belum ada laporan.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: docs.length,
                                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
                                itemBuilder: (context, index) {
                                  final data = docs[index].data() as Map<String, dynamic>;
                                  final String title = data['title'] ?? 'Tanpa Judul';
                                  final String location = data['location'] ?? 'Lokasi tidak diketahui';
                                  final String category = data['category'] ?? 'Umum';
                                  final int upvotes = data['upvotes'] ?? 0;
                                  final String urgency = data['urgency'] ?? 'RENDAH';
                                  final String coordsData = data['coordinates'] ?? location;

                                  IconData catIcon = Icons.warning_amber_rounded;
                                  Color catBgColor = Colors.orange.shade100;
                                  Color catIconColor = Colors.orange;

                                  if (category == 'Lampu Mati') {
                                    catIcon = Icons.lightbulb_outline;
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
                                  if (urgency.toUpperCase() == 'DARURAT') {
                                    urgencyColor = Colors.red;
                                  } else if (urgency.toUpperCase() == 'SEDANG') {
                                    urgencyColor = Colors.orange;
                                  }

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
                                      ],
                                    ),
                                    onTap: () => _openExternalMap(coordsData),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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
      decoration: const BoxDecoration(color: Color(0xFF1E1E96)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.priority_high,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Darurat',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
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
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sedang',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
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
                      child: Text(
                        'Rendah',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
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

  Widget _buildCustomMarker(Color color, String urgency, String category) {
    IconData icon = Icons.location_on;

    final String cat = category.toLowerCase();
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
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 16)),
        ),
        CustomPaint(painter: _TrianglePainter(color), size: const Size(12, 8)),
      ],
    );
  }

  Future<void> _shareReport(
    String title,
    String category,
    String urgency,
    String location,
  ) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan: $e')),
        );
      }
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => color != oldDelegate.color;
}
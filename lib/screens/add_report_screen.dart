import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({Key? key}) : super(key: key);

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Controller khusus untuk menyimpan teks alamat (disinkronkan dengan Autocomplete)
  final TextEditingController _locationController = TextEditingController();

  String _selectedUrgency = 'RENDAH';
  String _selectedCategory = 'Lampu Mati';

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isDataLoading = true;
  bool _isSearchingLocation = false;
  bool _showPlaceSuggestions = false;
  List<Map<String, dynamic>> _placeSuggestions = [];
  final Map<String, List<Map<String, dynamic>>> _suggestionCache = {};

  Timer? _debounceTimer;

  String currentUserId = "";
  String currentUserName = "Memuat nama...";

  LatLng? _selectedLocation;

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Lampu Mati',
      'icon': Icons.lightbulb_outline,
      'color': Colors.orange,
    },
    {
      'name': 'Area Gelap',
      'icon': Icons.dark_mode_outlined,
      'color': Colors.purple,
    },
    {
      'name': 'Rawan Kecelakaan',
      'icon': Icons.warning_amber_rounded,
      'color': Colors.red,
    },
    {'name': 'Kemacetan', 'icon': Icons.traffic_outlined, 'color': Colors.blue},
    {
      'name': 'Jalan Rusak',
      'icon': Icons.broken_image_outlined,
      'color': Colors.brown,
    },
    {
      'name': 'Rambu Rusak',
      'icon': Icons.construction_outlined,
      'color': Colors.indigo,
    },
    {'name': 'Banjir', 'icon': Icons.water_drop_outlined, 'color': Colors.cyan},
    {'name': 'Lainnya', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onLocationChanged);
    _loadUserData();
  }

  void _onLocationChanged() {
    _debounceTimer?.cancel();

    final String query = _locationController.text.trim();
    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _placeSuggestions = [];
          _showPlaceSuggestions = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _getPlaceSuggestions(query);
      if (!mounted) return;

      setState(() {
        _placeSuggestions = suggestions.toList();
        _showPlaceSuggestions = _placeSuggestions.isNotEmpty;
      });
    });
  }

  Future<void> _loadUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (!mounted) return;
        setState(() => currentUserId = user.uid);

        DataSnapshot snapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}/fullName')
            .get();
        if (!mounted) return;
        if (snapshot.exists) {
          setState(() => currentUserName = snapshot.value.toString());
        } else {
          setState(() => currentUserName = "Warga AmankanJalan");
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil profil: $e");
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationController.removeListener(_onLocationChanged);
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 15,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (pickedFile != null) setState(() => _imageFile = pickedFile);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil gambar: $e')));
    }
  }

  static Future<String> _encodeImageToBase64(XFile imageFile) async {
    List<int> imageBytes = await imageFile.readAsBytes();
    return base64Encode(imageBytes);
  }

  String _normalizeAddressQuery(String query) {
    String normalized = query.trim();
    normalized = normalized.replaceAll(RegExp(r'[.,;:]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.replaceAll(
      RegExp(r'\bjl\.?\b', caseSensitive: false),
      'Jalan',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\bjln\.?\b', caseSensitive: false),
      'Jalan',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\bgg\.?\b', caseSensitive: false),
      'Gang',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\bgang\.?\b', caseSensitive: false),
      'Gang',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\bkomp\.?\b', caseSensitive: false),
      'Komplek',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\bkomplek\b', caseSensitive: false),
      'Komplek',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!normalized.toLowerCase().contains('palembang')) {
      normalized = '$normalized, Palembang';
    }
    if (!normalized.toLowerCase().contains('sumatera selatan')) {
      normalized = '$normalized, Sumatera Selatan';
    }
    if (!normalized.toLowerCase().contains('indonesia')) {
      normalized = '$normalized, Indonesia';
    }
    return normalized;
  }

  List<String> _buildQueryVariants(String query) {
    final String normalized = _normalizeAddressQuery(query);
    final String raw = query.trim();
    final List<String> variants = [
      normalized,
      raw,
      '${raw.replaceAll(RegExp(r'\bjl\.?\b|\bjln\.?\b', caseSensitive: false), 'Jalan').trim()}, Palembang',
      '${raw.replaceAll(RegExp(r'\bjl\.?\b|\bjln\.?\b', caseSensitive: false), 'Jalan').trim()}, Palembang, Sumatera Selatan',
    ];

    final seen = <String>{};
    final uniqueVariants = <String>[];
    for (final variant in variants) {
      final key = variant.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (seen.add(key)) {
        uniqueVariants.add(variant);
      }
    }
    return uniqueVariants;
  }

  // Bounding box untuk Palembang (dengan margin lebih lebar)
  final double _minLat = -3.40;
  final double _maxLat = -2.80;
  final double _minLon = 104.50;
  final double _maxLon = 104.95;

  bool _isCoordinateInPalembang(double lat, double lon) {
    return lat >= _minLat && lat <= _maxLat && lon >= _minLon && lon <= _maxLon;
  }

  Future<List<Map<String, dynamic>>> _fetchNominatimSuggestions(
    String query,
  ) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'viewbox': '104.50,-3.40,104.95,-2.80',
      'bounded': '0',
      'limit': '10',
      'countrycodes': 'id',
      'addressdetails': '1',
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'AmankanJalanApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return const [];

      final List data = json.decode(response.body) as List;
      return data.map<Map<String, dynamic>>((e) {
        return {
          'display_name': e['display_name'],
          'lat': double.parse(e['lat'].toString()),
          'lon': double.parse(e['lon'].toString()),
        };
      }).toList();
    } catch (e) {
      debugPrint("Nominatim API error: $e");
      return const [];
    }
  }

  // --- FUNGSI AUTOCOMPLETE MENGAMBIL DATA DARI OPENSTREETMAP ---
  Future<Iterable<Map<String, dynamic>>> _getPlaceSuggestions(
    String query,
  ) async {
    if (query.isEmpty || query.length < 3)
      return const Iterable<Map<String, dynamic>>.empty();

    final String cacheKey = query
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cached = _suggestionCache[cacheKey];
    if (cached != null) return cached;

    setState(() => _isSearchingLocation = true);

    try {
      final results = <Map<String, dynamic>>[];

      for (final variant in _buildQueryVariants(query)) {
        final fetched = await _fetchNominatimSuggestions(variant);

        for (final item in fetched) {
          final lat = item['lat'] as double;
          final lon = item['lon'] as double;

          // Validasi: koordinat harus berada di dalam Palembang bounding box
          if (!_isCoordinateInPalembang(lat, lon)) {
            continue;
          }

          final alreadyExists = results.any(
            (existing) => existing['display_name'] == item['display_name'],
          );

          if (!alreadyExists) {
            results.add(item);
          }
        }

        // Jika sudah ada hasil yang cukup, stop
        if (results.length >= 5) break;
      }

      _suggestionCache[cacheKey] = results;
      return results;
    } catch (e) {
      debugPrint("Gagal mengambil saran alamat: $e");
      return const Iterable<Map<String, dynamic>>.empty();
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  Future<bool> _searchLocationFromText() async {
    final String query = _locationController.text.trim();
    if (query.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ketik minimal 3 karakter alamat.')),
      );
      return false;
    }

    setState(() {
      _isSearchingLocation = true;
      _showPlaceSuggestions = false;
    });

    try {
      final results = (await _getPlaceSuggestions(query)).toList();
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Alamat tidak ditemukan di kawasan Palembang. Coba pakai format: "Jl. Nama Jalan, Kecamatan, Palembang".',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return false;
      }

      final selected = results.first;
      final newLoc = LatLng(
        selected['lat'] as double,
        selected['lon'] as double,
      );

      if (!mounted) return false;
      setState(() {
        _selectedLocation = newLoc;
        _locationController.text = selected['display_name'] as String;
        _placeSuggestions = [];
        _showPlaceSuggestions = false;
      });
      FocusScope.of(context).unfocus();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mencari alamat: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    // Pastikan _locationController tidak kosong sebelum submit
    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap ketik atau pilih alamat lokasi dari daftar rekomendasi.',
          ),
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      final bool foundLocation = await _searchLocationFromText();
      if (!foundLocation || _selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Harap pilih alamat dari dropdown atau tekan cari lokasi.',
            ),
          ),
        );
        return;
      }
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap pilih alamat dari dropdown atau tekan cari lokasi.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_imageFile != null) {
        List<int> imageBytes = await _imageFile!.readAsBytes();
        if (imageBytes.length > 750000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ukuran foto terlalu besar.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
            setState(() => _isLoading = false);
            return;
          }
        }
        imageUrl = await compute(_encodeImageToBase64, _imageFile!);
      }

      String coordinates =
          '${_selectedLocation!.latitude},${_selectedLocation!.longitude}';

      await FirebaseFirestore.instance.collection('reports').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'coordinates': coordinates,
        'urgency': _selectedUrgency,
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'status': 'Aktif',
        'reporterId': currentUserId,
        'reporterName': currentUserName,
        'supportedBy': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil dikirim!')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan saat mengirim: $e')),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDataLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F0F5),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E1E96)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E96),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buat Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- KATEGORI ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategori Laporan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected =
                              _selectedCategory == category['name'];
                          return GestureDetector(
                            onTap: () => setState(
                              () => _selectedCategory = category['name'],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? category['color'].withOpacity(0.15)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? category['color']
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    category['icon'],
                                    color: category['color'],
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    category['name'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? category['color']
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- DETAIL & LOKASI ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail & Lokasi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildLabel('Judul Laporan *'),
                      TextFormField(
                        controller: _titleController,
                        minLines: 1,
                        maxLength: 100,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul tidak boleh kosong';
                          }
                          if (value.trim().length < 5) {
                            return 'Judul minimal 5 karakter';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Contoh: Lampu mati di...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Deskripsi *'),
                      TextFormField(
                        controller: _descController,
                        maxLength: 400,
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Deskripsi tidak boleh kosong';
                          }
                          if (value.trim().length < 10) {
                            return 'Deskripsi minimal 10 karakter';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Jelaskan kondisi...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Pilih Lokasi (Palembang) *'),
                          if (_isSearchingLocation)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              onTap: () {
                                if (_placeSuggestions.isNotEmpty) {
                                  setState(() => _showPlaceSuggestions = true);
                                }
                              },
                              onFieldSubmitted: (_) =>
                                  _searchLocationFromText(),
                              decoration: InputDecoration(
                                hintText:
                                    'Contoh: Jl. Rajawali, Ilir Timur II, Palembang',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF1E1E96),
                                ),
                                suffixIcon: _selectedLocation != null
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E96),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.white,
                              ),
                              onPressed: _searchLocationFromText,
                              tooltip: 'Cari lokasi',
                            ),
                          ),
                        ],
                      ),
                      if (_showPlaceSuggestions)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _isSearchingLocation
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _placeSuggestions.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: Colors.grey.shade200,
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final option = _placeSuggestions[index];
                                    final String addressName =
                                        option['display_name'] as String;
                                    final String shortAddress = addressName
                                        .split(',')
                                        .take(4)
                                        .join(', ');

                                    return ListTile(
                                      leading: const Icon(
                                        Icons.location_on,
                                        color: Color(0xFF1E1E96),
                                      ),
                                      title: Text(
                                        shortAddress,
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () {
                                        final newLoc = LatLng(
                                          option['lat'] as double,
                                          option['lon'] as double,
                                        );
                                        setState(() {
                                          _selectedLocation = newLoc;
                                          _locationController.text =
                                              addressName;
                                          _showPlaceSuggestions = false;
                                          _placeSuggestions = [];
                                        });
                                        FocusScope.of(context).unfocus();
                                      },
                                    );
                                  },
                                ),
                        ),

                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, bottom: 12.0),
                        child: Text(
                          '💡 Cara isi alamat: ketik nama jalan, nama tempat, atau kecamatan minimal 3 huruf, lalu pilih salah satu saran yang muncul. Contoh: Jl. Rajawali, Ilir Timur II, Palembang.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Tingkat Urgensi *'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedUrgency,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF1E1E96),
                            ),
                            items: ['RENDAH', 'SEDANG', 'DARURAT']
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (newValue) =>
                                setState(() => _selectedUrgency = newValue!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- FOTO SECTION ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildPhotoSection(),
                ),
                const SizedBox(height: 24),

                // --- SUBMIT BUTTON ---
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitReport,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Mengirim...' : 'Kirim Laporan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E96),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildRequiredFormField({
    required TextEditingController controller,
    required String hint,
    required String errorMessage,
  }) {
    return TextFormField(
      controller: controller,
      validator: (value) =>
          value == null || value.trim().isEmpty ? errorMessage : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Lokasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tambahkan foto (opsional)',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        if (_imageFile != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(
                        _imageFile!.path,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_imageFile!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _imageFile = null),
                  child: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 14,
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF1E1E96),
                ),
                label: const Text(
                  'Kamera',
                  style: TextStyle(color: Color(0xFF1E1E96)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF1E1E96)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(
                  Icons.image_outlined,
                  color: Color(0xFF1E1E96),
                ),
                label: const Text(
                  'Galeri',
                  style: TextStyle(color: Color(0xFF1E1E96)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF1E1E96)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

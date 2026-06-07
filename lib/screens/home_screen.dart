import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'add_report_screen.dart';
import 'report_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedUrgency = 'Semua';
  String _selectedCategory = 'Semua Kategori';
  String _searchQuery = '';
  final ScrollController _categoryScrollController = ScrollController();

  // Daftar kategori lengkap
  final List<Map<String, dynamic>> _allCategories = [
    {'name': 'Semua Kategori', 'icon': null},
    {'name': 'Lampu Mati', 'icon': Icons.lightbulb_outline},
    {'name': 'Area Gelap', 'icon': Icons.dark_mode_outlined},
    {'name': 'Rawan Kecelakaan', 'icon': Icons.warning_amber_rounded},
    {'name': 'Kemacetan', 'icon': Icons.traffic_outlined},
    {'name': 'Jalan Rusak', 'icon': Icons.broken_image_outlined},
    {'name': 'Rambu Rusak', 'icon': Icons.construction_outlined},
    {'name': 'Banjir', 'icon': Icons.water_drop_outlined},
    {'name': 'Lainnya', 'icon': Icons.more_horiz},
  ]; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSummaryCards(),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 16),
              _buildRecentReportsHeader(),
              _buildReportList(), 
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReportScreen()),
          );
        },
        backgroundColor: const Color(0xFF2A23C2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      // BOTTOM NAVIGATION SUDAH DIHAPUS DARI SINI
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E96),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Selamat Datang', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text('AmankanJalan', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() { _searchQuery = value.toLowerCase(); });
              },
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: 'Cari laporan...',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        int totalLaporan = 0;
        int totalDarurat = 0;
        int totalDitangani = 0;

        if (snapshot.hasData) {
          totalLaporan = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['urgency'] == 'DARURAT') totalDarurat++;
            if (data['status'] == 'Ditangani') totalDitangani++;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('$totalLaporan', 'Total Laporan', const Color(0xFFE6E6FA), Icons.warning_amber_rounded, const Color(0xFF5C5CFF)),
              _buildStatCard('$totalDarurat', 'Darurat', const Color(0xFFFFEBEB), Icons.error_outline, Colors.red),
              _buildStatCard('$totalDitangani', 'Ditangani', const Color(0xFFE8F8F5), Icons.check_circle_outline, Colors.teal),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String count, String label, Color bgColor, IconData icon, Color iconColor) {
    return Expanded(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(height: 4),
              Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- FILTER URGENCY ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Gunakan AlwaysScrollableScrollPhysics agar tetap terasa ada scroll meski konten sedikit
          physics: const AlwaysScrollableScrollPhysics(), 
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildUrgencyChip('Semua', _selectedUrgency == 'Semua'),
              _buildUrgencyChip('Darurat', _selectedUrgency == 'Darurat'),
              _buildUrgencyChip('Sedang', _selectedUrgency == 'Sedang'),
              _buildUrgencyChip('Rendah', _selectedUrgency == 'Rendah'),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // --- LABEL KATEGORI ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Semua Kategori', 
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)
          ),
        ),
        const SizedBox(height: 8),
        
        // --- FILTER KATEGORI (HORIZONTAL SCROLL DENGAN SCROLLBAR) ---
        SizedBox(
          height: 72, // lebih tinggi agar ada jarak antara chips dan scrollbar
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6), // beri ruang di bawah
            child: Scrollbar(
              controller: _categoryScrollController,
              thumbVisibility: true,
              thickness: 8,
              radius: const Radius.circular(8),
              child: ListView.separated(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _allCategories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = _allCategories[index];
                final isSelected = _selectedCategory == category['name'];

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category['name']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2A23C2) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2A23C2) : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Row(
                        children: [
                          if (category['icon'] != null) ...[
                            Icon(category['icon'], size: 14, color: isSelected ? Colors.white : Colors.orange),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            category['name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
  }

  Widget _buildUrgencyChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedUrgency = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2A23C2) : Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFF2A23C2) : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReportsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('Laporan Terkini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Real-time', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReportList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('Terjadi kesalahan memuat data.')));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('Belum ada laporan.\nKlik tombol + di bawah untuk menambahkan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
          );
        }

        var allDocs = snapshot.data!.docs;
        var filteredDocs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String urgencyDb = data['urgency'] ?? '';
          String categoryDb = data['category'] ?? '';
          String titleDb = (data['title'] ?? '').toLowerCase();
          String locationDb = (data['location'] ?? '').toLowerCase();

          bool matchSearch = _searchQuery.isEmpty || titleDb.contains(_searchQuery) || locationDb.contains(_searchQuery);
          bool matchUrgency = _selectedUrgency == 'Semua' || urgencyDb.toUpperCase() == _selectedUrgency.toUpperCase();
          bool matchCategory = _selectedCategory == 'Semua Kategori' || categoryDb == _selectedCategory;

          return matchSearch && matchUrgency && matchCategory;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: const [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tidak ada laporan yang sesuai pencarian atau filter.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            var data = doc.data() as Map<String, dynamic>;
            Color catBgColor = Colors.grey.shade100;
            Color catTextColor = Colors.grey.shade800;
            
            // Styling untuk setiap kategori
            if (data['category'] == 'Rawan Kecelakaan') {
              catBgColor = Colors.red.shade100;
              catTextColor = Colors.red;
            } else if (data['category'] == 'Area Gelap') {
              catBgColor = Colors.purple.shade100;
              catTextColor = Colors.purple;
            } else if (data['category'] == 'Lampu Mati') {
              catBgColor = Colors.orange.shade100;
              catTextColor = Colors.orange.shade900;
            } else if (data['category'] == 'Kemacetan') {
              catBgColor = Colors.blue.shade100;
              catTextColor = Colors.blue;
            } else if (data['category'] == 'Jalan Rusak') {
              catBgColor = Colors.brown.shade100;
              catTextColor = Colors.brown;
            } else if (data['category'] == 'Rambu Rusak') {
              catBgColor = Colors.indigo.shade100;
              catTextColor = Colors.indigo;
            } else if (data['category'] == 'Banjir') {
              catBgColor = Colors.cyan.shade100;
              catTextColor = Colors.cyan.shade900;
            }

            return _buildReportCard(
              context: context,
              docId: doc.id,
              rank: '#${index + 1}',
              category: data['category'] ?? 'Umum',
              urgency: data['urgency'] ?? 'RENDAH',
              title: data['title'] ?? '',
              location: data['location'] ?? '',
              description: data['description'] ?? '',
              upvotes: data['upvotes'] ?? 0,
              timeAgo: 'Baru saja', 
              categoryColor: catBgColor,
              categoryTextColor: catTextColor,
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard({
    required BuildContext context, required String docId, required String rank, required String category, required String urgency, required String title, required String location, required String description, required int upvotes, required String timeAgo, required Color categoryColor, required Color categoryTextColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ReportDetailScreen(docId: docId)));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: categoryColor, borderRadius: BorderRadius.circular(8)),
                        child: Text(category, style: TextStyle(color: categoryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: urgency.toUpperCase() == 'DARURAT' ? Colors.red : Colors.orange, borderRadius: BorderRadius.circular(8)),
                        child: Text(urgency, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2A23C2), borderRadius: BorderRadius.circular(8)),
                    child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(location, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(color: Colors.black87, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Aktif • $timeAgo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      // Tombol Bagikan
                      InkWell(
                        onTap: () {
                          _shareReport(title, category, urgency, location, description);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFE6F0FF), borderRadius: BorderRadius.circular(16)),
                          child: const Row(
                            children: [
                              Icon(Icons.share_outlined, size: 14, color: Color(0xFF2A23C2)),
                              SizedBox(width: 4),
                              Text('Bagikan', style: TextStyle(color: Color(0xFF2A23C2), fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Upvote
                      InkWell(
                        onTap: () {
                          FirebaseFirestore.instance.collection('reports').doc(docId).update({'upvotes': FieldValue.increment(1)});
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFE6E6FA), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_upward, size: 14, color: Color(0xFF2A23C2)),
                              const SizedBox(width: 4),
                              Text('$upvotes', style: const TextStyle(color: Color(0xFF2A23C2), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Fungsi untuk membagikan laporan
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
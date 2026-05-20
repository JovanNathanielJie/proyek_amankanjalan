import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_report_screen.dart';
import 'report_detail_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _selectedUrgency = 'Semua';
  String _selectedCategory = 'Semua Kategori';
  String _searchQuery = ''; // State baru untuk menyimpan teks pencarian

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        selectedItemColor: const Color(0xFF2A23C2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Peta'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
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
                  Text(
                    'Selamat Datang',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    'AmankanJalan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
              // Fungsi ini dipanggil setiap kali teks diubah oleh pengguna
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase(); // Ubah ke huruf kecil agar pencarian tidak case-sensitive
                });
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
            if (data['urgency'] == 'DARURAT') {
              totalDarurat++;
            }
            if (data['status'] == 'Ditangani') {
              totalDitangani++;
            }
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
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip('Semua', _selectedUrgency == 'Semua', true),
                _buildChip('Darurat', _selectedUrgency == 'Darurat', true),
                _buildChip('Sedang', _selectedUrgency == 'Sedang', true),
                _buildChip('Rendah', _selectedUrgency == 'Rendah', true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip('Semua Kategori', _selectedCategory == 'Semua Kategori', false),
                _buildChip('Lampu Mati', _selectedCategory == 'Lampu Mati', false, icon: Icons.lightbulb_outline),
                _buildChip('Area Gelap', _selectedCategory == 'Area Gelap', false, icon: Icons.dark_mode_outlined),
                _buildChip('Rawan Kecelakaan', _selectedCategory == 'Rawan Kecelakaan', false, icon: Icons.warning_amber_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, bool isUrgency, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        label: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.orange),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            if (isUrgency) {
              _selectedUrgency = label;
            } else {
              _selectedCategory = label;
            }
          });
        },
        selectedColor: const Color(0xFF2A23C2),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? const Color(0xFF2A23C2) : Colors.grey.shade300),
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
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true) 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('Terjadi kesalahan memuat data.')),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'Belum ada laporan.\nKlik tombol + di bawah untuk menambahkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        var allDocs = snapshot.data!.docs;
        
        var filteredDocs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          
          String urgencyDb = data['urgency'] ?? '';
          String categoryDb = data['category'] ?? '';
          
          // Ambil judul dan lokasi untuk dicocokkan dengan teks pencarian
          String titleDb = (data['title'] ?? '').toLowerCase();
          String locationDb = (data['location'] ?? '').toLowerCase();

          // 1. Cek apakah ada teks pencarian
          bool matchSearch = _searchQuery.isEmpty || 
                             titleDb.contains(_searchQuery) || 
                             locationDb.contains(_searchQuery);

          // 2. Cek filter urgensi
          bool matchUrgency = _selectedUrgency == 'Semua' || 
                              urgencyDb.toUpperCase() == _selectedUrgency.toUpperCase();

          // 3. Cek filter kategori
          bool matchCategory = _selectedCategory == 'Semua Kategori' || 
                               categoryDb == _selectedCategory;

          // Data akan ditampilkan jika memenuhi KETIGA syarat filter ini
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
                  Text(
                    'Tidak ada laporan yang sesuai pencarian atau filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
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

            Color catBgColor = Colors.blue.shade100;
            Color catTextColor = Colors.blue.shade800;
            
            if (data['category'] == 'Rawan Kecelakaan') {
              catBgColor = Colors.red.shade100;
              catTextColor = Colors.red;
            } else if (data['category'] == 'Area Gelap') {
              catBgColor = Colors.purple.shade100;
              catTextColor = Colors.purple;
            } else if (data['category'] == 'Lampu Mati') {
              catBgColor = Colors.orange.shade100;
              catTextColor = Colors.orange.shade900;
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
    required BuildContext context,
    required String docId,
    required String rank,
    required String category,
    required String urgency,
    required String title,
    required String location,
    required String description,
    required int upvotes,
    required String timeAgo,
    required Color categoryColor,
    required Color categoryTextColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDetailScreen(docId: docId),
            ),
          );
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
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(category, style: TextStyle(color: categoryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: urgency.toUpperCase() == 'DARURAT' ? Colors.red : Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(urgency, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A23C2),
                      borderRadius: BorderRadius.circular(8),
                    ),
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
              Text(
                description,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Aktif • $timeAgo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  // Tombol Upvote di Card Home Screen (Tetap dibiarkan jika ingin bisa upvote langsung dari depan)
                  InkWell(
                    onTap: () {
                      FirebaseFirestore.instance.collection('reports').doc(docId).update({
                        'upvotes': FieldValue.increment(1)
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E6FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
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
              )
            ],
          ),
        ),
      ),
    );
  }
}
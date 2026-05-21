import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';

import 'edit_profile_screen.dart';
import 'login_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mengambil instance user yang sedang login dari Firebase Auth
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- FUNGSI UNTUK MENAMPILKAN DIALOG KONFIRMASI KELUAR ---
  Future<bool?> _showLogoutDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Keluar Akun?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Anda akan keluar dari akun ini. Apakah Anda yakin?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6E6FA), 
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                        label: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F), 
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jika user belum login, tampilkan tombol untuk ke halaman login
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F0F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Anda belum masuk akun', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                },
                child: const Text('Login Sekarang'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      // 1. STREAM BUILDER PERTAMA: MENDENGARKAN DATA USER DARI REALTIME DATABASE SECARA OTOMATIS
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/${currentUser!.uid}').onValue,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Ekstrak data user dari Realtime Database
          Map<dynamic, dynamic>? userData;
          if (userSnapshot.hasData && userSnapshot.data!.snapshot.value != null) {
            userData = userSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          }

          // Nilai default jika data kosong (Fallback)
          String fullName = userData?['fullName'] ?? 'Pengguna';
          String username = userData?['username'] ?? 'username';
          String phoneNumber = userData?['phoneNumber'] ?? '-';

          // 2. STREAM BUILDER KEDUA: MENDENGARKAN DATA LAPORAN FIRESTORE
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('reports').snapshots(),
            builder: (context, reportSnapshot) {
              if (reportSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<DocumentSnapshot> myReports = [];
              if (reportSnapshot.hasData) {
                myReports = reportSnapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  // Filter laporan berdasarkan UID user yang sedang login
                  return data['reporterId'] == currentUser!.uid;
                }).toList();
              }

              myReports.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                Timestamp timeA = dataA['timestamp'] ?? Timestamp.now();
                Timestamp timeB = dataB['timestamp'] ?? Timestamp.now();
                return timeB.compareTo(timeA);
              });

              // Kalkulasi Statistik
              int totalLaporan = myReports.length;
              int totalUpvoteDiterima = 0;
              int totalDitangani = 0;
              int totalAktif = 0;
              bool hasTrending = false;
              bool hasTopReporter = false;

              for (var doc in myReports) {
                var data = doc.data() as Map<String, dynamic>;
                int upvotes = data['upvotes'] ?? 0;
                totalUpvoteDiterima += upvotes;

                if (data['status'] == 'Ditangani') {
                  totalDitangani++;
                } else {
                  totalAktif++; 
                }

                if (upvotes > 50) hasTrending = true;
                if (upvotes >= 25) hasTopReporter = true;
              }

              bool badgePelaporAktif = totalLaporan >= 5;
              bool badgeTrending = hasTrending;
              bool badgeGuardian = totalLaporan >= 1; 
              bool badgeTopReporter = hasTopReporter;

              return SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Mengirimkan data dinamis ke komponen Header
                      _buildHeader(context, fullName, username, phoneNumber),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            _buildStatsGrid(totalLaporan, totalUpvoteDiterima, totalDitangani, totalAktif),
                            const SizedBox(height: 16),
                            _buildAchievements(badgePelaporAktif, badgeTrending, badgeGuardian, badgeTopReporter),
                            const SizedBox(height: 16),
                            _buildRecentReports(myReports),
                            const SizedBox(height: 16),
                            // Mengirimkan username ke seksi Akun
                            _buildAccountSection(context, username), 
                            const SizedBox(height: 16),
                            _buildEmergencyInfo(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- KOMPONEN HEADER YANG DIUPDATE ---
  Widget _buildHeader(BuildContext context, String fullName, String username, String phoneNumber) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E96),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40, color: Color(0xFF1E1E96)),
          ),
          const SizedBox(height: 16),
          // Menampilkan Nama Lengkap yang Asli
          Text(
            fullName,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bersama Menjaga Keselamatan Jalan',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield, color: Colors.orange, size: 16),
                SizedBox(width: 6),
                Text('Guardian Level 3', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              // Melempar data yang asli ke halaman Edit Profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    currentFullName: fullName,
                    currentUsername: username,
                    currentPhoneNumber: phoneNumber,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit, color: Colors.white, size: 16),
            label: const Text('Edit Profil', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int laporan, int upvotes, int ditangani, int aktif) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(laporan.toString(), 'Total Laporan', Icons.description_outlined, Colors.purple),
        _buildStatCard(upvotes.toString(), 'Upvote Diterima', Icons.arrow_upward, Colors.teal),
        _buildStatCard(ditangani.toString(), 'Ditangani', Icons.check_circle_outline, Colors.orange),
        _buildStatCard(aktif.toString(), 'Aktif', Icons.error_outline, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAchievements(bool pelaporAktif, bool trending, bool guardian, bool topReporter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pencapaian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildBadgeCard('Pelapor Aktif', '5+ laporan', Icons.flag, pelaporAktif),
              _buildBadgeCard('Trending', 'Laporan viral', Icons.trending_up, trending),
              _buildBadgeCard('Guardian', 'Jaga keamanan', Icons.shield, guardian),
              _buildBadgeCard('Top Reporter', 'Laporan terbaik', Icons.star, topReporter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(String title, String subtitle, IconData icon, bool isAchieved) {
    Color bgColor = isAchieved ? const Color(0xFFE6E6FA) : Colors.grey.shade100;
    Color iconBgColor = isAchieved ? const Color(0xFF1E1E96) : Colors.grey.shade400;
    Color textColor = isAchieved ? Colors.black87 : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAchieved ? const Color(0xFF1E1E96).withOpacity(0.3) : Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildRecentReports(List<DocumentSnapshot> myReports) {
    int displayCount = min(3, myReports.length);
    List<DocumentSnapshot> recentReports = myReports.sublist(0, displayCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Laporan Terbaru Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (recentReports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: Text('Belum ada laporan yang dibuat.', style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentReports.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                var data = recentReports[index].data() as Map<String, dynamic>;
                String title = data['title'] ?? 'Tanpa Judul';
                int upvotes = data['upvotes'] ?? 0;
                String status = data['status'] ?? 'aktif';
                String category = data['category'] ?? 'Umum';

                IconData catIcon = Icons.warning_amber_rounded;
                Color catBg = Colors.orange.shade100;
                Color catIconColor = Colors.orange;

                if (category == 'Lampu Mati') {
                  catIcon = Icons.lightbulb_outline;
                  catBg = Colors.orange.shade100;
                  catIconColor = Colors.orange;
                } else if (category == 'Rawan Kecelakaan') {
                  catIcon = Icons.warning_amber_rounded;
                  catBg = Colors.red.shade100;
                  catIconColor = Colors.red;
                } else if (category == 'Area Gelap') {
                  catIcon = Icons.dark_mode_outlined;
                  catBg = Colors.purple.shade100;
                  catIconColor = Colors.purple;
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(8)),
                    child: Icon(catIcon, color: catIconColor),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('$upvotes upvote • $status', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- SEKSI AKUN YANG DIUPDATE ---
  Widget _buildAccountSection(BuildContext context, String username) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          // Menampilkan Username yang Asli
          Text('@${username.toLowerCase()}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                bool? confirm = await _showLogoutDialog();
                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Anda telah berhasil keluar.')),
                    );
                    // Pindah secara menyeluruh kembali ke Login Screen
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout, color: Colors.deepOrange),
              label: const Text('Keluar Akun', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepOrange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Penting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildEmergencyTile(Icons.phone_in_talk, 'Polisi Lalu Lintas', '112'),
          Divider(color: Colors.grey.shade200),
          _buildEmergencyTile(Icons.phone_in_talk, 'Damkar & Kedaruratan', '113'),
          Divider(color: Colors.grey.shade200),
          _buildEmergencyTile(Icons.info_outline, 'BPJT (Jalan Tol)', '11000'),
        ],
      ),
    );
  }

  Widget _buildEmergencyTile(IconData icon, String title, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E6FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1E1E96), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(number, style: const TextStyle(color: Color(0xFF1E1E96), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
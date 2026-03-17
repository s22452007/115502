import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';

// 🌟 新增了側邊欄會用到的檔案引入
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;

  final List<String> _tabs = ['週排名', '好友排名', '學習小組'];

  final List<Map<String, dynamic>> _weeklyUsers = [
    {'name': 'Din', 'points': 3500, 'rank': 1},
    {'name': 'yoi', 'points': 3000, 'rank': 2},
    {'name': 'fewr', 'points': 2980, 'rank': 3},
    {'name': 'xuan', 'points': 2540, 'rank': 4},
    {'name': 'fjdis', 'points': 2350, 'rank': 5},
    {'name': 'rvr', 'points': 2000, 'rank': 6},
    {'name': 'yexw', 'points': 1875, 'rank': 7},
  ];

  final List<Map<String, dynamic>> _friendUsers = [
    {'name': 'Din', 'points': 3500, 'rank': 1},
    {'name': 'Yu', 'points': 3000, 'rank': 2},
    {'name': 'fewr', 'points': 2980, 'rank': 3},
    {'name': 'xuan', 'points': 2540, 'rank': 4},
    {'name': 'fjdis', 'points': 2350, 'rank': 5},
  ];

  List<Map<String, dynamic>> get _currentUsers {
    if (_tab == 0) return _weeklyUsers;
    if (_tab == 1) return _friendUsers;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F2),

      // 🌟 1. 裝上側邊欄抽屜！
      drawer: _buildDrawer(context),

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        // 🌟 2. 讓漢堡選單可以點擊打開抽屜
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        // 🌟 3. 讓相機圖示可以點擊跳轉
        title: IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // tab 區
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF5B8B5A), width: 1.2),
            ),
            child: Row(
              children: _tabs.asMap().entries.map((e) {
                final bool isSelected = _tab == e.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = e.key),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7EA37B)
                            : const Color(0xFFE9E9E9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        e.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w400,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _tab == 2
                ? _buildStudyGroupTab()
                : _buildRankingTab(_currentUsers),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 3, // 🌟 排行榜通常是 index 3 (看你的首頁設定)
        onTap: (i) {
          if (i == 3) return; // 如果點自己就不動

          if (i == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
              // 🌟 假設首頁是 index 2
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildRankingTab(List<Map<String, dynamic>> users) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final u = users[i];
        final bool isTop3 = u['rank'] <= 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isTop3 ? const Color(0xFFE8DCAA) : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${u['rank']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        u['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${u['points']} points',
                      style: const TextStyle(
                        color: Color(0xFF6E7F6E),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudyGroupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8DCAA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'study group',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8DCAA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Shared Goal: 5000 points',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(color: AppColors.primary),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(color: const Color(0xFFDCEAD9)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '3000/5000',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已提醒隊友')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Remind Teammates',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 完美移植首頁的側邊欄 (包含朋友寫的大頭貼功能！)
  Widget _buildDrawer(BuildContext context) {
    final userAvatar = context.watch<UserProvider>().avatar;
    final userEmail =
        context.watch<UserProvider>().email ?? 'guest@example.com';
    final userName = userEmail.split('@')[0];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF6AA86B)),
            accountName: Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color(0xFFC5E1A5),
              backgroundImage: userAvatar != null
                  ? MemoryImage(base64Decode(userAvatar))
                  : null,
              child: userAvatar == null
                  ? const Icon(Icons.person, size: 50, color: Color(0xFF333333))
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('回首頁', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context); // 關抽屜
              Navigator.pushReplacement(
                // 跳轉首頁
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('個人檔案', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('我的單字探險', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResultGalleryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.stars, color: Colors.orange),
            title: const Text(
              '訂閱與點數',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('系統設定', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              '登出',
              style: TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

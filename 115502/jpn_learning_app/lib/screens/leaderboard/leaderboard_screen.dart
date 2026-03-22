import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
// 引入剛剛修改完的學習小組主畫面
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';

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
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
                        color: isSelected ? const Color(0xFF7EA37B) : const Color(0xFFE9E9E9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        e.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
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
            // 🌟 核心修改處：切到第3個 Tab 時，直接載入已寫好的 StudyGroupScreen，並且關閉其自帶的 AppBar！
            child: _tab == 2
                ? const StudyGroupScreen(showAppBar: false)
                : _buildRankingTab(_currentUsers),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 3) return;
          if (i == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          } else if (i == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
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
              SizedBox(width: 28, child: Text('${u['rank']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(width: 12),
              CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.person, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text('${u['points']} points', style: const TextStyle(color: Color(0xFF6E7F6E), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
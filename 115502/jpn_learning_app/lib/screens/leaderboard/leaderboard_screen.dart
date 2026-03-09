import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';

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
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.white),
        title: const Icon(Icons.camera_alt, color: Colors.white),
        centerTitle: true,
        actions: const [
          Icon(Icons.person_outline, color: Colors.white),
          SizedBox(width: 12),
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
              border: Border.all(
                color: const Color(0xFF5B8B5A),
                width: 1.2,
              ),
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
        currentIndex: 1,
        onTap: (i) {
          if (i == 1) return;

          if (i == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
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
            color: isTop3
                ? const Color(0xFFE8DCAA)
                : const Color(0xFFE8E8E8),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已提醒隊友')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Remind Teammates',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
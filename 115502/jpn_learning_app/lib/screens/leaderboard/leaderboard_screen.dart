import 'package:flutter/material.dart';
import 'package:jpn_learning_app_new/utils/constants.dart';
import 'package:jpn_learning_app_new/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app_new/screens/leaderboard/study_group_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;
  final List<String> _tabs = ['週排名', '總排名', '好友排名'];
  final List<Map<String, dynamic>> _users = [
    {'name': 'Din', 'points': 3500, 'rank': 1},
    {'name': 'yoi', 'points': 3000, 'rank': 2},
    {'name': 'fewr', 'points': 2980, 'rank': 3},
    {'name': 'xuan', 'points': 2540, 'rank': 4},
    {'name': 'fjdis', 'points': 2350, 'rank': 5},
    {'name': 'rvr', 'points': 2000, 'rank': 6},
    {'name': 'yexw', 'points': 1875, 'rank': 7},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Icon(Icons.menu, color: Colors.white),
        title: Icon(Icons.camera_alt, color: Colors.white),
        centerTitle: true,
        actions: [Icon(Icons.person_outline, color: Colors.white), const SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Tab 切換
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _tabs.asMap().entries.map((e) => GestureDetector(
              onTap: () => setState(() => _tab = e.key),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _tab == e.key ? AppColors.primary : AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(e.value, style: TextStyle(
                  color: _tab == e.key ? Colors.white : AppColors.textDark, fontSize: 14)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          // 排行列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final u = _users[i];
                final isTop3 = i < 3;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isTop3 ? AppColors.cardYellow : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 28, child: Text('${u['rank']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                      const SizedBox(width: 12),
                      CircleAvatar(radius: 20, backgroundColor: AppColors.primaryLighter,
                          child: Icon(Icons.person, color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${u['points']}  points', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      ])),
                    ],
                  ),
                );
              },
            ),
          ),
          // 學習小組按鈕
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('查看學習小組', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(currentIndex: 3, onTap: (_) {}),
    );
  }
}

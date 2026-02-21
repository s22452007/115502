import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 今日任務
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardYellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今日任務', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 0.6, backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 8,
                      ),
                    )),
                    const SizedBox(width: 8),
                    Text('已完成2/3禮拜', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ]),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: const Text('繼續', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 好友活動
            const Text('好友活動', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _FriendTile(name: 'Din', activity: '進行了「閱讀」系數'),
            const SizedBox(height: 8),
            _FriendTile(name: 'Pio', activity: '完成了「御茶屋餐廳」情境'),
            const SizedBox(height: 16),
            // 每日推薦
            const Text('每日推薦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  const Text('試試「探索居酒屋場景吧！」', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String name, activity;
  const _FriendTile({required this.name, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 18, backgroundColor: AppColors.primaryLighter,
            child: Icon(Icons.person, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(activity, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ]),
      ],
    );
  }
}

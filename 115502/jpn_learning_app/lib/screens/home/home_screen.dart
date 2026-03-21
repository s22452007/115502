import 'dart:ui'; // 🔽 新增這個：為了實作高級的毛玻璃 (Blur) 效果
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';

import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart'; // 手動搜尋
import 'package:jpn_learning_app/screens/scenario/role_play_intro_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/leaderboard_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/profile/photo_folder_v2_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2; // 預設停留在首頁

  final Color _goalGreen = const Color(0xFF6AA86B);
  final Color _cardRed = const Color.fromARGB(255, 133, 109, 160);
  final Color _cardBlue = const Color(0xFF85B8D6);
  final Color _textColor = const Color(0xFF333333);
  final Color _subTextColor = const Color(0xFF888888);

  // 🌟 全新升級：帶有毛玻璃與懸浮按鈕的解鎖遮罩
  Widget _buildPremiumLockedOverlay({
    required Widget child,
    required String message,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 底層：原本的UI (透明度降低，並防止點擊)
        Opacity(
          opacity: 0.35, // 讓底下的卡片變淡
          child: IgnorePointer(
            // 防止訪客點擊底下的功能
            child: child,
          ),
        ),
        // 中層：一點點毛玻璃效果
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: Container(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        // 上層：懸浮標語與登入按鈕
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75), // 帶有質感的半透明黑底
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _goalGreen, // 使用你主題的綠色
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '去登入',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 將「今日目標」原本的綠色卡片抽出來成為獨立方法
  Widget _buildDailyGoalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _goalGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _goalGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '探索3個新場景',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (context.watch<UserProvider>().dailyScans / 3.0).clamp(
                0.0,
                1.0,
              ),
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '進度 : ${context.watch<UserProvider>().dailyScans}/3',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _goalGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  children: [
                    Text('開啟相機', style: TextStyle(fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward_outlined, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 將「學習小組」原本的白底卡片抽出來成為獨立方法
  Widget _buildStudyGroupCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.amber.shade100,
            child: const Text(
              'D',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Din',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '獲得了「麵食大師」徽章',
                  style: TextStyle(fontSize: 13, color: _subTextColor),
                ),
              ],
            ),
          ),
          Text(
            '10m',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail =
        context.watch<UserProvider>().email ?? 'guest@example.com';
    final userName = userEmail.split('@')[0];
    final streakDays = context.watch<UserProvider>().streakDays;
    final jPts = context.watch<UserProvider>().jPts;
    final isGuest = context.watch<UserProvider>().userId == null;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primary, // 或是你剛剛設定的 AppColors.primary
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),

        // 1. 中間改回原本的相機 Icon
        title: IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CameraScreen(),
              ), // 幫你把原本無效的跳轉修好，直接導向相機頁面
            );
          },
        ),
        centerTitle: true,

        actions: [
          // 2. 右邊只保留原本的個人檔案 Icon
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '早安，$userName!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '今天也是學習日語的好日子',
              style: TextStyle(fontSize: 14, color: _subTextColor),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildStatusChip(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  text: isGuest ? '登入挑戰' : '連續$streakDays天',
                  borderColor: Colors.orange.shade200,
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (!isGuest) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BuyPointsScreen(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  child: _buildStatusChip(
                    icon: Icons.monetization_on,
                    iconColor: Colors.blue,
                    text: isGuest ? '0 J-Pts' : '$jPts J-Pts',
                    borderColor: Colors.blue.shade200,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const Text(
              '今日學習目標',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 🎯 今日學習目標區塊：套用全新遮罩
            isGuest
                ? _buildPremiumLockedOverlay(
                    child: _buildDailyGoalCard(context),
                    message: '登入啟用今日目標',
                  )
                : _buildDailyGoalCard(context),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近解鎖場景',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PhotoFolderV2Screen()),
                    );
                  },
                  child: Text(
                    '查看收藏夾 >',
                    style: TextStyle(
                      fontSize: 14,
                      color: _goalGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RolePlayIntroScreen(
                            imagePath:
                                'https://images.unsplash.com/photo-1542051812891-60521138a209?q=80&w=800&auto=format&fit=crop',
                          ),
                        ),
                      );
                    },
                    child: _buildSceneCard(
                      '一蘭拉麵店',
                      '12個新單字',
                      Icons.ramen_dining,
                      _cardRed,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RolePlayIntroScreen(
                            imagePath:
                                'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=800&auto=format&fit=crop',
                          ),
                        ),
                      );
                    },
                    child: _buildSceneCard(
                      '新宿車站',
                      '8個新單字',
                      Icons.train,
                      _cardBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '學習小組動態',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    );
                  },
                  child: Text(
                    '排行榜 >',
                    style: TextStyle(
                      fontSize: 14,
                      color: _goalGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 👥 學習小組區塊：套用全新遮罩
            isGuest
                ? _buildPremiumLockedOverlay(
                    child: _buildStudyGroupCard(context),
                    message: '登入查看群組動態',
                  )
                : GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudyGroupScreen(),
                        ),
                      );
                    },
                    child: _buildStudyGroupCard(context),
                  ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          }
          if (i == 1) {
            // 這是你剛剛做好的手動搜尋！
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
            );
          }
          if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneCard(
    String title,
    String subtitle,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: _subTextColor)),
        ],
      ),
    );
  }
}

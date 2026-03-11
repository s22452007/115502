import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';

// --- 這裡把你截圖裡的所有重要檔案都引入進來了！ ---
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/leaderboard_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2; // 預設停留在首頁

  // 設計圖裡的顏色
  final Color _goalGreen = const Color(0xFF6AA86B);
  final Color _cardRed = const Color.fromARGB(255, 133, 109, 160);
  final Color _cardBlue = const Color(0xFF85B8D6);
  final Color _textColor = const Color(0xFF333333);
  final Color _subTextColor = const Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    // 從 Provider 抓取使用者的 Email (如果是訪客沒登入，就給個預設值)
    final userEmail =
        context.watch<UserProvider>().email ?? 'guest@example.com';
    // 把 Email 的 @ 前面切出來當作名字
    final userName = userEmail.split('@')[0];
    // 抓取名字的第一個字母當作頭像 (並轉成大寫)
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: Colors.white,

      drawer: _buildDrawer(context, userName, userEmail, firstLetter),

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
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

            // --- 點數與天數區塊 ---
            Row(
              children: [
                _buildStatusChip(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  text: '連續5天',
                  borderColor: Colors.orange.shade200,
                ),
                const SizedBox(width: 12),

                // 🌟 連線 1：點擊 J-Pts 跳轉到 PremiumScreen
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    );
                  },
                  child: _buildStatusChip(
                    icon: Icons.monetization_on,
                    iconColor: Colors.blue,
                    text: '120 J-Pts',
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
            Container(
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
                      value: 0.66,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '進度 : 2/3',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CameraScreen(),
                            ),
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
                            Text(
                              '開啟相機',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.arrow_forward_outlined, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                      MaterialPageRoute(
                        builder: (_) => const ResultGalleryScreen(),
                      ),
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
                  child: _buildSceneCard(
                    '一蘭拉麵店',
                    '12個新單字',
                    Icons.ramen_dining,
                    _cardRed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSceneCard(
                    '新宿車站',
                    '8個新單字',
                    Icons.train,
                    _cardBlue,
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

                // 🌟 連線 2：點擊「排行榜 >」跳轉到 LeaderboardScreen
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

            // 🌟 連線 3：點擊動態卡片跳轉到 StudyGroupScreen
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyGroupScreen()),
                );
              },
              child: Container(
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '獲得了「麵食大師」徽章',
                            style: TextStyle(
                              fontSize: 13,
                              color: _subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '10m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      // 底部導覽列
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          // 如果你的底部導覽列 Index 3 是排行榜，也可以在這裡加：
          if (i == 3)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            );
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

  Widget _buildDrawer(
    BuildContext context,
    String userName,
    String userEmail,
    String firstLetter,
  ) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: _goalGreen),
            accountName: Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF6AA86B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('回首頁', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
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

          // 👇 就是這裡！我幫你把訂閱與點數完美安插進來了！ 👇
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
              Navigator.pop(context); // 先關抽屜
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()), // 跳轉
              );
            },
          ),
          const Divider(),

          // 👆 就是這裡！ 👆
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

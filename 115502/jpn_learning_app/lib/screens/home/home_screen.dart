import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
// 這裡先註解掉，因為我們還沒建立排行榜的檔案
// import 'package:jpn_learning_app/screens/leaderboard/leaderboard_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2; // 預設停留在首頁 (假設 index 2 是首頁)

  // 設計圖裡的顏色
  final Color _goalGreen = const Color(0xFF6AA86B);
  final Color _cardRed = const Color(0xFFE58888);
  final Color _cardBlue = const Color(0xFF85B8D6);
  final Color _textColor = const Color(0xFF333333);
  final Color _subTextColor = const Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // 🌟 這裡幫你把原本的 Header (AppBar) 加回來了！
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

      // 下方是絕美的新版內容
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. 頂部招呼語 ---
            Text(
              '早安，Pin!',
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

            // --- 2. 連續天數 & 點數 (Chips) ---
            Row(
              children: [
                _buildStatusChip(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  text: '連續5天',
                  borderColor: Colors.orange.shade200,
                ),
                const SizedBox(width: 12),
                _buildStatusChip(
                  icon: Icons.monetization_on,
                  iconColor: Colors.blue,
                  text: '120 J-Pts',
                  borderColor: Colors.blue.shade200,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- 3. 今日學習目標 (綠色大卡片) ---
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
                  // 進度條
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
                      // 開啟相機按鈕
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

            // --- 4. 最近解鎖場景 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近解鎖場景',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    // 點擊查看收藏夾，進入單字畫廊
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

            // --- 5. 學習小組動態 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '學習小組動態',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {},
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
            Container(
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
            ),
            const SizedBox(height: 20), // 底部留白
          ],
        ),
      ),

      // --- 底部導覽列 ---
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
        },
      ),
    );
  }

  // --- 小元件：連續天數與點數標籤 ---
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

  // --- 小元件：場景卡片 ---
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

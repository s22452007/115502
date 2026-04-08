import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // 帶有一點點灰藍的柔和背景色
      body: SafeArea(
        // 💡 加上 SingleChildScrollView 讓畫面可以上下捲動，完美解決破版問題！
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                const SizedBox(height: 20),
                // --- 歡迎標題區 ---
                Text(
                  'ようこそ！',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.green.shade600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '歡迎來到 J-Lens\n請選擇您的日文起點',
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    height: 1.4, 
                    color: Color(0xFF1E293B)
                  ),
                ),
                const SizedBox(height: 40),

                // --- 卡片 1：我是新手 (移除 Expanded，讓卡片根據內容自動決定高度) ---
                _buildSelectionCard(
                  context: context,
                  title: '我是日文新手',
                  subtitle: '從五十音開始，穩紮穩打建立基礎，適合完全沒有接觸過日文的你。',
                  icon: Icons.spa_rounded, 
                  gradientColors: [Colors.green.shade400, Colors.teal.shade500],
                  shadowColor: Colors.green.withOpacity(0.3),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('正在為您設定新手模式...')),
                    );

                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId != null) {
                      await ApiClient.updateLevel(currentUserId, 'N5');
                    }

                    // 確認畫面還在，更新 Provider 狀態
                    if (!context.mounted) return;
                    context.read<UserProvider>().setJapaneseLevel('N5');

                    // 3. 噴發迎新彈窗！(傳入 level_01 並且 level 是 1)
                    // 程式會停在這裡，直到使用者按下彈窗的「開始探索！」
                    await LevelUpDialog.show(context, badgeId: 'level_01', level: 1);

                    // 4. 彈窗關閉後，正式帶使用者進首頁
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                ),
                
                const SizedBox(height: 24),

                // --- 卡片 2：我已經有基礎了 (一樣移除 Expanded) ---
                _buildSelectionCard(
                  context: context,
                  title: '我已經有點基礎',
                  subtitle: '進行 10 題階梯式快速測驗，AI 將為您量身打造專屬的學習起點。',
                  icon: Icons.school_rounded, 
                  gradientColors: [Colors.blue.shade400, Colors.indigo.shade500],
                  shadowColor: Colors.blue.withOpacity(0.3),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuickTestScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🎨 抽離出來的卡片 UI 元件
  // ==========================================
  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15, 
                color: Colors.white.withOpacity(0.9), 
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
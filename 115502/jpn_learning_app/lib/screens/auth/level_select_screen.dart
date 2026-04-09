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
      backgroundColor: Colors.white, // 回歸純白背景
      body: SafeArea(
        child: SingleChildScrollView( // 保留滑動功能，防止小螢幕破版
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // 改回置中對齊，看起來更穩重
              children: [
                const SizedBox(height: 20),
                const Text(
                  '歡迎來到 J-Lens',
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '請選擇您的日文學習起點',
                  style: TextStyle(
                    fontSize: 16, 
                    color: Colors.black54
                  ),
                ),
                const SizedBox(height: 48),

                // --- 卡片 1：我是新手 (純淨綠色外框版) ---
                _buildFlatCard(
                  context: context,
                  title: '我是日文新手',
                  subtitle: '從五十音開始打穩基礎\n適合完全沒學過日文的你',
                  icon: Icons.spa_outlined, // 使用空心圖示更輕量
                  mainColor: Colors.green,
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('正在為您設定新手模式...')),
                    );

                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId != null) {
                      await ApiClient.updateLevel(currentUserId, 'N5');
                    }

                    if (context.mounted) {
                      context.read<UserProvider>().setJapaneseLevel('N5');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                ),
                
                const SizedBox(height: 24),

                // --- 卡片 2：我已經有基礎了 (純淨藍色外框版) ---
                _buildFlatCard(
                  context: context,
                  title: '我已經有點基礎',
                  subtitle: '進行 10 題快速測驗\nAI 將為您量身打造專屬起點',
                  icon: Icons.school_outlined, // 使用空心圖示
                  mainColor: Colors.blue,
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
  // 🎨 乾淨扁平化卡片 UI 元件 (無漸層、無圓形底圖)
  // ==========================================
  Widget _buildFlatCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color mainColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          // 極淡的背景色 + 乾淨的實線外框
          color: mainColor.withOpacity(0.05),
          border: Border.all(color: mainColor.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 乾淨俐落的純圖示，沒有多餘的圓圈底色
            Icon(icon, size: 56, color: mainColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: mainColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14, 
                color: Colors.black87, 
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
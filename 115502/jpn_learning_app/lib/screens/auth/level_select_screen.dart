// ==========================================
// 1. 系統內建與第三方套件
// ==========================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ==========================================
// 2. 本地端服務與工具
// ==========================================
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

// ==========================================
// 3. 狀態提供者 (Providers)
// ==========================================
import 'package:jpn_learning_app/providers/user_provider.dart';

// ==========================================
// 4. 畫面路由跳轉 (Screens)
// ==========================================
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

// ==========================================
// 5. 獨立 UI 元件與彈出視窗
// ==========================================
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 🌟 統一改為左對齊，更有專業感
              children: [
                const SizedBox(height: 20),
                const Text(
                  'WELCOME TO J-LENS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '請選擇您的\n日文學習起點',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                // 裝飾用小綠條
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 48),

                // --- 卡片 1：我是新手 ---
                _buildModernCard(
                  context: context,
                  title: '我是日文新手',
                  subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
                  mainColor: AppColors.primary,
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('正在為您設定新手模式...'),
                        backgroundColor: AppColors.primary,
                      ),
                    );

                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId != null) {
                      await ApiClient.updateLevel(currentUserId, 'N5');
                    }

                    if (!context.mounted) return;
                    context.read<UserProvider>().setJapaneseLevel('N5');
                    await LevelUpDialog.show(context, badgeId: 'level_01', level: 1);

                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                ),
                
                const SizedBox(height: 20),

                // --- 卡片 2：我已經有基礎了 ---
                _buildModernCard(
                  context: context,
                  title: '我已經有基礎了',
                  subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
                  mainColor: const Color(0xFF444444), // 使用深灰色區隔選項
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuickTestScreen()),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🎨 Commit 1 重頭戲：無圖示極簡卡片元件
  // ==========================================
  Widget _buildModernCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color mainColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          // 🌟 關鍵：移除 Icon 後，改用左側粗邊框作為視覺重心
          border: Border(
            left: BorderSide(color: mainColor, width: 6),
            top: BorderSide(color: mainColor.withOpacity(0.1), width: 1),
            right: BorderSide(color: mainColor.withOpacity(0.1), width: 1),
            bottom: BorderSide(color: mainColor.withOpacity(0.1), width: 1),
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: mainColor.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 🌟 內容靠左排版
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.w900, 
                color: mainColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15, 
                color: Colors.black.withOpacity(0.6),
                height: 1.6, // 增加行高讓文字更易讀
              ),
            ),
          ],
        ),
      ),
    );
  }
}
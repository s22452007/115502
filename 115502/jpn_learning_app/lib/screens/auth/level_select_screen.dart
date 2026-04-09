// ==========================================
// 1. 系統內建與第三方套件 (Core & Packages)
// ==========================================
import 'package:flutter/material.dart';          // Flutter 核心 Material 設計元件庫
import 'package:provider/provider.dart';         // 狀態管理套件

// ==========================================
// 2. 本地端服務與工具 (Local Services & Utils)
// ==========================================
import 'package:jpn_learning_app/utils/api_client.dart';       // 負責與後端 Flask API 溝通的工具類別
import 'package:jpn_learning_app/utils/constants.dart';      // 📌 引入 APP 統一色系設定

// ==========================================
// 3. 狀態提供者 (Providers)
// ==========================================
import 'package:jpn_learning_app/providers/user_provider.dart';// 提供全域的使用者資料 (如 userId, japaneseLevel)

// ==========================================
// 4. 畫面路由跳轉 (Screens)
// ==========================================
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart'; // 10 題快速測驗畫面
import 'package:jpn_learning_app/screens/home/home_screen.dart';       // APP 主要首頁畫面

/// **[程度選擇畫面 (Level Select Screen)]**
/// 位於註冊後 / 登入後的第一個破冰畫面。
/// 提供使用者兩個選項：「我是新手」或「我已經有基礎了」。
/// 用意在於分流，避免有程度的學生被強迫從五十音開始學起。
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 📌 使用 APP 統一的背景色
      backgroundColor: AppColors.background, 
      body: SafeArea(
        child: SingleChildScrollView( // 保留滑動功能，防止小螢幕破版
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // 置中對齊
              children: [
                const SizedBox(height: 20),
                Text(
                  '歡迎來到 J-Lens',
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    // 📌 使用 APP 統一的深色文字
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '請選擇您的日文學習起點',
                  style: TextStyle(
                    fontSize: 16, 
                    // 📌 使用 APP 統一的次要文字顏色
                   color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 48),

                // --- 卡片 1：我是新手 ---
                _buildFlatCard(
                  context: context,
                  title: '我是日文新手',
                  subtitle: '從五十音開始打穩基礎\n適合完全沒學過日文的你',
                  icon: Icons.spa_outlined, 
                  // 📌 統一使用 APP 的主色系
                  mainColor: AppColors.primary,
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('正在為您設定新手模式...'),
                        backgroundColor: AppColors.primary, // SnackBar 顏色也統一
                      ),
                    );

                    // 1. 取得目前登入者的 ID
                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId != null) {
                      // 2. 呼叫後端 API，強制將該使用者的程度更新為最基礎的 'N5'
                      await ApiClient.updateLevel(currentUserId, 'N5');
                    }

                    // 3. 更新成功後，更新本地端 Provider 狀態，並跳轉至首頁
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

                // --- 卡片 2：我已經有基礎了 ---
                _buildFlatCard(
                  context: context,
                  title: '我已經有點基礎',
                  subtitle: '進行 10 題快速測驗\nAI 將為您量身打造專屬起點',
                  icon: Icons.school_outlined, 
                  // 📌 第二個卡片也使用主色，以維持畫面一致性
                  mainColor: AppColors.primary,
                  onTap: () {
                    // 若有基礎，則跳轉至「10題快速測驗」畫面進行程度判定
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
  // 🎨 乾淨扁平化卡片 UI 元件 (符合 App 風格)
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
      borderRadius: BorderRadius.circular(16), // 圓角保持與其他按鈕一致
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white, // 卡片底色改為純白，在米白背景上會有很好的層次感
          border: Border.all(color: mainColor.withOpacity(0.3), width: 1.5), // 更輕量柔和的邊框
          borderRadius: BorderRadius.circular(16),
          // 加上極為輕微的陰影，增加立體感但不會顯得花俏
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              style: TextStyle(
                fontSize: 14, 
                color: Colors.black54, // 使用統一的次要文字色
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
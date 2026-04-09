// ==========================================
// 1. 系統內建與第三方套件 (Core & Packages)
// ==========================================
import 'package:flutter/material.dart';          // Flutter 核心 Material 設計元件庫
import 'package:provider/provider.dart';         // 狀態管理套件 (負責呼叫 context.read)

// ==========================================
// 2. 本地端服務與工具 (Local Services & Utils)
// ==========================================
import 'package:jpn_learning_app/utils/api_client.dart';       // 負責與後端 Flask API 溝通的工具類別
import 'package:jpn_learning_app/utils/constants.dart';        // 🎨 引入 APP 統一色系設定 (AppColors)

// ==========================================
// 3. 狀態提供者 (Providers)
// ==========================================
import 'package:jpn_learning_app/providers/user_provider.dart';// 提供全域的使用者資料 (如 userId, japaneseLevel)

// ==========================================
// 4. 畫面路由跳轉 (Screens)
// ==========================================
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart'; // 10 題快速測驗畫面
import 'package:jpn_learning_app/screens/home/home_screen.dart';       // APP 主要首頁畫面

// ==========================================
// 5. 獨立 UI 元件與彈出視窗 (Widgets & Dialogs)
// ==========================================
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart'; // 🎉 迎新禮包！華麗的徽章升級慶祝彈窗

/// **[程度選擇畫面 (Level Select Screen)]**
/// 位於註冊後 / 登入後的第一個破冰畫面。
/// 提供使用者兩個選項：「我是新手」或「我已經有基礎了」。
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎨 使用朋友設定的 APP 統一背景色
      backgroundColor: AppColors.background, 
      body: SafeArea(
        child: SingleChildScrollView( 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // 置中對齊，看起來更穩重
              children: [
                const SizedBox(height: 20),
                const Text(
                  '歡迎來到 J-Lens',
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '請選擇您的日文學習起點',
                  style: TextStyle(
                    fontSize: 16, 
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 48),

                // --- 卡片 1：我是新手 ---
                _buildFlatCard(
                  context: context,
                  title: '我是日文新手',
                  subtitle: '從五十音開始打穩基礎\n適合完全沒學過日文的你',
                  icon: Icons.spa_outlined, // 使用空心圖示更輕量
                  mainColor: AppColors.primary,
                  onTap: () async {
                    // 1. 顯示提示字 (套用朋友的 UI 顏色)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('正在為您設定新手模式...'),
                        backgroundColor: AppColors.primary, 
                      ),
                    );

                    // 2. 更新後端與 Provider 的等級資料
                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId != null) {
                      await ApiClient.updateLevel(currentUserId, 'N5');
                    }

                    // 確認畫面還在，更新 Provider 狀態
                    if (!context.mounted) return;
                    context.read<UserProvider>().setJapaneseLevel('N5');

                    // 3. 噴發迎新彈窗！(這就是被朋友不小心刪掉的靈魂邏輯，幫你加回來了)
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

                // --- 卡片 2：我已經有基礎了 ---
                _buildFlatCard(
                  context: context,
                  title: '我已經有點基礎',
                  subtitle: '進行 10 題快速測驗\nAI 將為您量身打造專屬起點',
                  icon: Icons.school_outlined, 
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
            // 乾淨俐落的純圖示
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
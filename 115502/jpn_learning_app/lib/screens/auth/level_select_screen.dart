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

// 🌟 Commit 2 改動：將 StatelessWidget 改為 StatefulWidget 以管理選取狀態
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  // 🌟 追蹤目前選中的索引 (0: 新手, 1: 基礎)
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  index: 0,
                  title: '我是日文新手',
                  subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
                  activeColor: AppColors.primary,
                  onTap: () async {
                    setState(() => _selectedIndex = 0); // 🌟 更新狀態
                    
                    // 執行原本的邏輯
                    final currentUserId = context.read<UserProvider>().userId;
                    if (currentUserId != null) {
                      await ApiClient.updateLevel(currentUserId, 'N5');
                    }
                    if (!context.mounted) return;
                    context.read<UserProvider>().setJapaneseLevel('N5');
                    await LevelUpDialog.show(context, badgeId: 'level_01', level: 1);
                    if (context.mounted) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                    }
                  },
                ),
                
                const SizedBox(height: 24),

                // --- 卡片 2：我已經有基礎了 ---
                _buildModernCard(
                  index: 1,
                  title: '我已經有基礎了',
                  subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
                  activeColor: const Color(0xFF444444),
                  onTap: () {
                    setState(() => _selectedIndex = 1); // 🌟 更新狀態
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickTestScreen()));
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
  // 🎨 Commit 2 重頭戲：支援動態選取狀態的卡片
  // ==========================================
  Widget _buildModernCard({
    required int index,
    required String title,
    required String subtitle,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    // 🌟 判斷目前是否被選中
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        // 🌟 未選中且已有其他卡片被選中時，變淡
        opacity: (_selectedIndex != null && !isSelected) ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              // 🌟 選中時邊框變粗
              left: BorderSide(color: isSelected ? activeColor : Colors.grey.shade300, width: isSelected ? 8 : 4),
              top: BorderSide(color: isSelected ? activeColor.withOpacity(0.1) : Colors.grey.shade200, width: 1),
              right: BorderSide(color: isSelected ? activeColor.withOpacity(0.1) : Colors.grey.shade200, width: 1),
              bottom: BorderSide(color: isSelected ? activeColor.withOpacity(0.1) : Colors.grey.shade200, width: 1),
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isSelected ? activeColor.withOpacity(0.1) : Colors.black.withOpacity(0.02),
                blurRadius: isSelected ? 20 : 10,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                  color: isSelected ? activeColor : Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15, 
                  color: isSelected ? activeColor.withOpacity(0.7) : Colors.black.withOpacity(0.6),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
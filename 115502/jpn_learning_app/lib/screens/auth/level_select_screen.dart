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

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int? _selectedIndex;

  // 🌟 將執行邏輯封裝，讓程式碼更乾淨
  Future<void> _handleNavigation() async {
    if (_selectedIndex == 0) {
      // 邏輯 1：新手路徑
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('正在為您設定新手模式...'), backgroundColor: AppColors.primary),
      );

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
    } else {
      // 邏輯 2：測驗路徑
      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickTestScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'WELCOME TO J-LENS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 2.0),
              ),
              const SizedBox(height: 12),
              const Text(
                '請選擇您的\n日文學習起點',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2),
              ),
              const SizedBox(height: 48),

              // --- 選項 1 ---
              _buildModernCard(
                index: 0,
                title: '我是日文新手',
                subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
                activeColor: AppColors.primary,
              ),
              
              const SizedBox(height: 20),

              // --- 選項 2 ---
              _buildModernCard(
                index: 1,
                title: '我已經有基礎了',
                subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
                activeColor: const Color(0xFF444444),
              ),

              const Spacer(), // 🌟 自動撐開空間，將按鈕推到底部

              // --- 🌟 Commit 3 重頭戲：底部確認按鈕 ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _selectedIndex != null ? _handleNavigation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _selectedIndex == null ? '請選擇一個起點' : '開始體驗',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required int index,
    required String title,
    required String subtitle,
    required Color activeColor,
  }) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index), // 🌟 點擊僅負責切換狀態
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeColor.withOpacity(0.15) : Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row( // 🌟 稍微調整內部排版，加入選中勾選視覺
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
                ],
              ),
            ),
            if (isSelected) 
              Icon(Icons.check_circle, color: activeColor, size: 28),
          ],
        ),
      ),
    );
  }
}
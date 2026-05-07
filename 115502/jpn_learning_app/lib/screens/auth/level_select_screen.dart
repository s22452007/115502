import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int? _selectedIndex;

  Future<void> _handleNavigation() async {
    if (_selectedIndex == 0) {
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
    } else if (_selectedIndex == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickTestScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32), // 🌟 稍微加寬邊距，讓對齊線更明顯
          child: Column(
            // 🌟 核心：確保 Column 內所有組件從左側 0 座標開始
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              const SizedBox(height: 20),
              const Text(
                'WELCOME TO J-LENS',
                textAlign: TextAlign.left, // 🌟 強制文字內部左對齊
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.bold, 
                  color: AppColors.primary, 
                  letterSpacing: 1.5
                ),
              ),
              const SizedBox(height: 16),
              // 🌟 這裡做了換行優化與強制左對齊
              const Text(
                '請選擇您的\n日文學習起點',
                textAlign: TextAlign.left, // 🌟 關鍵修正：確保兩行文字的起點完全重合
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.black87, 
                  height: 1.25, 
                ),
              ),
              const SizedBox(height: 20),
              // 🌟 裝飾條：確保寬度從左側出發
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 48),

              // 下方的卡片與按鈕保持原本的流暢邏輯...
              _buildFluidCard(
                index: 0,
                title: '我是日文新手',
                subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
              ),
              
              const SizedBox(height: 24),

              _buildFluidCard(
                index: 1,
                title: '我已經有基礎了',
                subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
              ),

              const Spacer(),

              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  onPressed: _selectedIndex != null ? _handleNavigation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: _selectedIndex != null ? 6 : 0,
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

  // 🌟 卡片內部也同步強化左對齊
  Widget _buildFluidCard({required int index, required String title, required String subtitle}) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        scale: isSelected ? 1.02 : 1.0,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.05),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 🌟 確保卡片內文字也是絕對左對齊
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected ? AppColors.primary : Colors.black87
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14, 
                        color: isSelected ? AppColors.primary.withOpacity(0.8) : Colors.black54, 
                        height: 1.5
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) 
                Icon(Icons.check_circle, color: AppColors.primary, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
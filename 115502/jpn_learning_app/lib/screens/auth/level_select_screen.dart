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

  // 🌟 定義統一的動畫參數，確保內外同步
  static const _syncDuration = Duration(milliseconds: 700); // 稍微調快一點點點，讓同步感更紮實
  static const _syncCurve = Curves.fastOutSlowIn;

  Future<void> _handleNavigation() async {
    // ... 保留強大的 API 與導航邏輯 ...
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
    const TextStyle titleStyle = TextStyle(
      fontSize: 32, 
      fontWeight: FontWeight.w900, 
      color: Colors.black87,
      height: 1.2,
      fontFamily: '微軟正黑體',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'WELCOME TO J-LENS',
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.bold, 
                  color: AppColors.primary, 
                  letterSpacing: 2.0
                ),
              ),
              const SizedBox(height: 20),

              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('請選擇你的', style: titleStyle),
                  Text('日文學習起點', style: titleStyle),
                ],
              ),

              const SizedBox(height: 20),
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 48),

              // 🌟 呼叫完美同步的卡片
              _buildSyncedCard(
                index: 0,
                title: '我是日文新手',
                subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
              ),
              
              const SizedBox(height: 24),

              _buildSyncedCard(
                index: 1,
                title: '我已經有基礎了',
                subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
              ),

              const Spacer(),

              // 底部按鈕
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutQuart,
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: '微軟正黑體'),
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

  // 🌟 核心修復：完美同步文字與邊框的卡片
  Widget _buildSyncedCard({required int index, required String title, required String subtitle}) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 600), // 保持獨立的輕微物理縮放
        scale: isSelected ? 1.02 : 1.0,
        curve: Curves.easeOutBack, 
        child: AnimatedContainer(
          // 🌟 關鍵 1：Container 動態效果
          duration: _syncDuration, 
          curve: _syncCurve, 
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.05),
              width: isSelected ? 2.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.black.withOpacity(0.02),
                blurRadius: isSelected ? 20 : 10,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🌟 關鍵 2：使用 AnimatedDefaultTextStyle 同步標題顏色
                    AnimatedDefaultTextStyle(
                      duration: _syncDuration, // 使用統一時間
                      curve: _syncCurve, // 使用統一曲線
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        fontFamily: '微軟正黑體', // 確保字型一致
                        color: isSelected ? AppColors.primary : Colors.black87, // 🌟 這裡的顏色變更會變成動畫
                      ),
                      child: Text(title),
                    ),
                    const SizedBox(height: 10),
                    // 🌟 關鍵 3：使用 AnimatedDefaultTextStyle 同步副標題顏色
                    AnimatedDefaultTextStyle(
                      duration: _syncDuration, // 使用統一時間
                      curve: _syncCurve, // 使用統一曲線
                      style: TextStyle(
                        fontSize: 14, 
                        fontFamily: '微軟正黑體',
                        color: isSelected ? AppColors.primary.withOpacity(0.8) : Colors.black54, // 🌟 這裡的顏色變更會變成動畫
                        height: 1.5
                      ),
                      child: Text(subtitle),
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
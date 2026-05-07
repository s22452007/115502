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

  // 🌟 極致同步參數：大幅縮短時間，改用剛硬曲線以減少「波浪感」🌟
  static const _syncDuration = Duration(milliseconds: 400); // 從 700ms 降至 400ms
  static const _syncCurve = Curves.easeOutQuad; // 🌟 採用更精確、減速更快的曲線

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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 2.0),
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

              // 🌟 呼叫極簡對齊版本的卡片
              _buildMinimalCard(
                index: 0,
                title: '我是日文新手',
                subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
              ),
              
              const SizedBox(height: 24),

              _buildMinimalCard(
                index: 1,
                title: '我已經有基礎了',
                subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
              ),

              const Spacer(),

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
                    elevation: _selectedIndex != null ? 4 : 0,
                  ),
                  child: Text(
                    _selectedIndex == null ? '請選擇一個起點' : '開始體驗', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: '微軟正黑體')
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

  // 🌟 核心：消除「波浪感」的極簡回饋卡片
  Widget _buildMinimalCard({required int index, required String title, required String subtitle}) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250), // 🌟 縮短時間，大幅減少波浪感
        scale: isSelected ? 1.01 : 1.0, 
        curve: _syncCurve, // 🌟 使用與顏色統一的精確曲線，移除彈性
        child: AnimatedContainer(
          duration: _syncDuration, // 大幅縮短
          curve: _syncCurve, // 大幅減少波浪感
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: _syncDuration, // 同步大幅縮短
                      curve: _syncCurve, // 同步剛硬曲線
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        fontFamily: '微軟正黑體',
                        color: isSelected ? AppColors.primary : Colors.black87,
                      ),
                      child: Text(title),
                    ),
                    const SizedBox(height: 10),
                    AnimatedDefaultTextStyle(
                      duration: _syncDuration, // 同步大幅縮短
                      curve: _syncCurve, // 同步剛硬曲線
                      style: TextStyle(
                        fontSize: 14, 
                        fontFamily: '微軟正黑體',
                        color: isSelected ? AppColors.primary.withOpacity(0.8) : Colors.black54, 
                        height: 1.5
                      ),
                      child: Text(subtitle),
                    ),
                  ],
                ),
              ),
              // Fade 效果也同步變快，消除飄浮感
              AnimatedOpacity(
                duration: _syncDuration, 
                curve: _syncCurve, 
                opacity: isSelected ? 1.0 : 0.0,
                child: Icon(Icons.check_circle, color: AppColors.primary, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
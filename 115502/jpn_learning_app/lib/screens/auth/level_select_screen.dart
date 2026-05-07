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

  // 🌟 動態同步參數：讓顏色過渡維持優雅的慢速
  static const _syncDuration = Duration(milliseconds: 700);
  static const _syncCurve = Curves.fastOutSlowIn;

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

              _buildRefinedCard(
                index: 0,
                title: '我是日文新手',
                subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
              ),
              
              const SizedBox(height: 24),

              _buildRefinedCard(
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
                  child: const Text('開始體驗', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 核心：移除強烈跳動，改為細膩回饋
  Widget _buildRefinedCard({required int index, required String title, required String subtitle}) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400), // 🌟 縮短時間，更 snappy
        scale: isSelected ? 1.01 : 1.0, // 🌟 降低縮放比例，從 1.02 降至 1.01
        curve: Curves.easeOutCubic, // 🌟 移除彈跳，改用平滑曲線
        child: AnimatedContainer(
          duration: _syncDuration,
          curve: _syncCurve,
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
                      duration: _syncDuration,
                      curve: _syncCurve,
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected ? AppColors.primary : Colors.black87,
                      ),
                      child: Text(title),
                    ),
                    const SizedBox(height: 10),
                    AnimatedDefaultTextStyle(
                      duration: _syncDuration,
                      curve: _syncCurve,
                      style: TextStyle(
                        fontSize: 14, 
                        color: isSelected ? AppColors.primary.withOpacity(0.8) : Colors.black54, 
                        height: 1.5
                      ),
                      child: Text(subtitle),
                    ),
                  ],
                ),
              ),
              // 勾選圓圈使用 Fade 效果代替跳出，視覺更穩
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
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
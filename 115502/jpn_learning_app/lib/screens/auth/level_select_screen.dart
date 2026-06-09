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

  static const _goldenDuration = Duration(milliseconds: 280); 
  static const _smoothCurve = Curves.easeOutCubic;

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);

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
      color: Color(0xFF2C3E50), 
      height: 1.2,
      fontFamily: '微軟正黑體',
    );

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'WELCOME TO Snap to Learn',
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

              _buildGoldenCard(
                index: 0,
                title: '我是日文新手',
                subtitle: '從五十音開始打穩基礎，\n適合完全沒學過日文的您。',
              ),
              
              const SizedBox(height: 24),

              _buildGoldenCard(
                index: 1,
                title: '我已經有基礎了',
                subtitle: '進行 10 題快速測驗，\nAI 將為您量身打造專屬起點。',
              ),

              const Spacer(),

              // Commit 3: 底部按鈕完全扁平化，增加大圓角
              AnimatedContainer(
                duration: _goldenDuration,
                curve: _smoothCurve,
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _selectedIndex != null ? _handleNavigation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0, // 徹底扁平化
                  ),
                  child: const Text('開始體驗', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: '微軟正黑體')),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoldenCard({required int index, required String title, required String subtitle}) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedScale(
        duration: _goldenDuration,
        scale: isSelected ? 1.015 : 1.0, 
        curve: _smoothCurve,
        child: AnimatedContainer(
          duration: _goldenDuration,
          curve: _smoothCurve,
          width: double.infinity,
          padding: const EdgeInsets.all(26), // 稍微加大內邊距，看起來更大氣
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.1),
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: _goldenDuration,
                      curve: _smoothCurve,
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        fontFamily: '微軟正黑體',
                        color: isSelected ? AppColors.primary : Color(0xFF2C3E50),
                      ),
                      child: Text(title),
                    ),
                    const SizedBox(height: 12),
                    AnimatedDefaultTextStyle(
                      duration: _goldenDuration,
                      curve: _smoothCurve,
                      style: TextStyle(
                        fontSize: 14, 
                        fontFamily: '微軟正黑體',
                        color: isSelected ? AppColors.primary.withOpacity(0.8) : Colors.black54, 
                        height: 1.6
                      ),
                      child: Text(subtitle),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: _goldenDuration,
                curve: _smoothCurve,
                opacity: isSelected ? 1.0 : 0.0,
                child: Icon(Icons.check_circle, color: AppColors.primary, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
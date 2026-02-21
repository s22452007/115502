import 'package:flutter/material.dart';
import 'package:jpn_learning_app_new/utils/constants.dart';
import 'package:jpn_learning_app_new/screens/auth/quick_test_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final levels = [
      {'title': '超級新手', 'desc': '什麼都不懂，好想學習自立'},
      {'title': '入門新手', 'desc': '會5字、能進行基本生活旅行，了解日文字母'},
      {'title': '初級應用 (N5、N4)', 'desc': '板燈學基本生活句型，合場景，認識隱形無漢語'},
      {'title': '中級對話 (N3以上)', 'desc': '能大致溝通日常生活語言到此，需要自立學習法'},
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('歡迎加入我們！\n請選擇您目前的日語程度',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 32),
              ...levels.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LevelButton(
                  title: l['title']!,
                  desc: l['desc']!,
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const QuickTestScreen())),
                ),
              )),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const QuickTestScreen())),
                  child: Text('我不確定，進行測驗', style: TextStyle(color: AppColors.textGrey)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('確定並案組始學習', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final String title, desc;
  final VoidCallback onTap;
  const _LevelButton({required this.title, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

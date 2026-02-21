import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/test_result_screen.dart';

class QuickTestScreen extends StatefulWidget {
  const QuickTestScreen({Key? key}) : super(key: key);

  @override
  State<QuickTestScreen> createState() => _QuickTestScreenState();
}

class _QuickTestScreenState extends State<QuickTestScreen> {
  int _selected = -1;

  final List<String> _options = ['A. はい、お願いします。', 'B. いいえ、結構です', 'C. 温めています。'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('快速測驗 (1/5)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('情境題：便利商店', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('店員問：お弁当は温めますか？\n你想回答：好的，麻煩了。\n請選哪一個？',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ..._options.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _selected = e.key),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: _selected == e.key ? AppColors.primary : AppColors.primaryLighter,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                          color: _selected == e.key ? Colors.white : AppColors.textDark,
                          fontSize: 15,
                        )),
                  ),
                ),
              )),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const TestResultScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('下一題', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

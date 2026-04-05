import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '歡迎加入！\n請選擇您的日文程度',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),

              // 按鈕 1：我是日文新手 (略過測驗)
              InkWell(
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正在為您設定新手模式...')),
                  );

                  final currentUserId = context.read<UserProvider>().userId;
                  if (currentUserId != null) {
                    // 【關鍵】：直接呼叫現有的 update_level，並寫入乾淨的 N5
                    await ApiClient.updateLevel(currentUserId, 'N5');
                  }

                  if (context.mounted) {
                    context.read<UserProvider>().setJapaneseLevel('N5');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.egg_alt_outlined, size: 48, color: Colors.green),
                      SizedBox(height: 12),
                      Text('我是日文新手', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      SizedBox(height: 4),
                      Text('從五十音開始打穩基礎', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // 按鈕 2：我已經有點基礎了 (進入 10 題測驗)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuickTestScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.school_outlined, size: 48, color: Colors.blue),
                      SizedBox(height: 12),
                      Text('我已經有點基礎了', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                      SizedBox(height: 4),
                      Text('進行 10 題測驗，為您量身打造起點', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
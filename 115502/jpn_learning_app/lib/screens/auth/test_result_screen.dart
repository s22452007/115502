import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/widgets/radar_chart.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart'; // 確保路徑正確

class TestResultScreen extends StatelessWidget {
  final int score;

  const TestResultScreen({Key? key, required this.score}) : super(key: key);

  // 1. 保留原本的大寫字母等級 (為了符合你的設計圖視覺)
  String get grade {
    if (score >= 80) return 'S';
    if (score >= 60) return 'A';
    if (score >= 40) return 'B';
    return 'C';
  }

  // 2. 新增：根據分數判定日語程度 (你可以根據需求調整分數門檻)
  String get levelName {
    if (score >= 80) return '中級對話(N3以上)';
    if (score >= 60) return '初級應用(N5、N4)';
    if (score >= 40) return '入門新手';
    return '超級新手';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // 加入 SingleChildScrollView 讓畫面可以滑動，解決 Overflow 破版問題！
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                '測驗完成',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 等級字母與插圖
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    grade,
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade400,
                      shadows: const [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.sentiment_very_satisfied, size: 80, color: Colors.pinkAccent),
                ],
              ),
              
              const SizedBox(height: 12),
              // 動態顯示判定結果的程度
              Text(
                '判定程度：$levelName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 20),

              // 分數與雷達圖卡片 (移除 Expanded，改用 Container 讓它自然撐開)
              Container(
                width: double.infinity,
                // 增加上下 padding，給雷達圖的 Listening、Reading 等文字留出空間
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32), 
                decoration: BoxDecoration(
                  color: Colors.lightGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: $score/100',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40), // 讓分數與圖表保持距離
                    const Center(
                      child: RadarChartWidget(
                        // 這裡之後可以串接真正的各項能力分數
                        scores: [0.9, 0.7, 0.85, 0.6, 0.8], 
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // 底部按鈕 - 檢討錯題
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('準備開發：檢討錯題功能')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // AppColors.primary
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('檢討錯題', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              
              // 底部按鈕 - 開始探索 (儲存等級並跳回首頁)
              ElevatedButton(
                onPressed: () {
                  // 1. 把判定的等級存進 UserProvider
                  context.read<UserProvider>().setJapaneseLevel(levelName);
                  
                  // 2. 直接跳轉到首頁，並清空先前的測驗畫面堆疊
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.2), // AppColors.primaryLighter
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('開始探索', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
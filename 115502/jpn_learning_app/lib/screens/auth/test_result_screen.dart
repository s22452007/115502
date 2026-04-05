import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class TestResultScreen extends StatelessWidget {
  final String levelCode; // 後端傳來的乾淨代碼 (N5, N4, N3, N2, N1)

  const TestResultScreen({Key? key, required this.levelCode}) : super(key: key);

  // 前端自己負責將代碼轉為 UI 文字
  String get displayTitle {
    switch (levelCode) {
      case 'N1': return '日語大師 (N1)';
      case 'N2': return '商務菁英 (N2)';
      case 'N3': return '高級對話 (N3)';
      case 'N4': return '中級應用 (N4)';
      case 'N5': default: return '入門新手 (N5)';
    }
  }

  // 給予相對應的字母評分視覺
  String get gradeVisual {
    switch (levelCode) {
      case 'N1': return 'S';
      case 'N2': return 'A';
      case 'N3': return 'B';
      case 'N4': return 'C';
      case 'N5': default: return 'D';
    }
  }

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
                '測驗完成！',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    gradeVisual,
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade400,
                      shadows: const [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.verified, size: 80, color: Colors.green),
                ],
              ),
              
              const SizedBox(height: 24),
              const Text('為您分配的起點程度為：', style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 8),
              
              Text(
                displayTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
              ),

              const SizedBox(height: 48),

              // 因為已經存入資料庫了，按此按鈕直接回家
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('開始探索', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
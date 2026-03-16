import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/scene_result_screen.dart';
import 'package:jpn_learning_app/services/ai_service.dart';

// 2-2-2 AI 分析中
class AnalyzingScreen extends StatefulWidget {
  final String imagePath; // 新增：接收圖片路徑

  const AnalyzingScreen({Key? key, required this.imagePath}) : super(key: key);
  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      // 呼叫 AI 服務分析圖片
      final result = await AiService().analyzeScene(widget.imagePath);

      if (mounted && result != null && result['result'] != null) {
        // 成功後，導向辨識結果頁面，並將結果傳過去 (SceneResultScreen 需要修改來接收資料)
        // 為了不一次修改太多，這裡先維持原本的導向，我們稍後再處理 SceneResultScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SceneResultScreen()),
        );
      } else {
        _showErrorDialog('分析失敗，請重試');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 關閉 Dialog
              Navigator.pop(context); // 退回相機頁
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt, size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ai is analyzing object....',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

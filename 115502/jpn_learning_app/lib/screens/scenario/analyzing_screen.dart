import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/scene_result_screen.dart';
import 'package:jpn_learning_app/services/ai_service.dart';

import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

// 2-2-2 AI 分析中
class AnalyzingScreen extends StatefulWidget {
  final String imagePath; // 接收圖片路徑

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
        
        // 分析成功，把今日進度 +1
        final userId = context.read<UserProvider>().userId;
        if (userId != null) {
          // 不是訪客，才呼叫後端 API 增加進度
          final progressResult = await ApiClient.incrementDailyScan(userId);
          
          if (mounted && progressResult.containsKey('daily_scans')) {
            // 把後端算好的最新進度 (例如從 0 變 1)，更新到大腦裡！
            context.read<UserProvider>().setDailyScans(progressResult['daily_scans']);
          }
        }

        if (!mounted) return;
        
        // 成功後，導向辨識結果頁面
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
              decoration: const BoxDecoration(
                color: AppColors.primaryLighter,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ai is analyzing object....',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
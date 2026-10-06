import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/scene_result_screen.dart';
import 'package:jpn_learning_app/widgets/common/analyzing_stage_view.dart';

import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

/// 拍照辨識進行中的畫面。
///
/// 辨識全部在後端一次完成，前端無法即時得知進度，
/// 因此這裡依「後端實際的處理順序」用時間推進階段提示，
/// 讓使用者知道系統在做什麼、還在動，而不是只有一個轉圈圈。
/// 畫面本體（圖示、階段清單、安心提示）抽成 AnalyzingStageView，
/// 朗讀評分的等待畫面也用同一套，兩邊規格才會一致。
class AnalyzingScreen extends StatefulWidget {
  final String imagePath; // 接收圖片路徑
  final String? customTitle; // 新增自訂標題
  final String? contextDescription; // 使用者描述的當下情境（選填）
  final int? assignmentId; // 從作業進來才有，後端辨識完會自動繳交

  const AnalyzingScreen({
    Key? key,
    required this.imagePath,
    this.customTitle,
    this.contextDescription,
    this.assignmentId,
  }) : super(key: key);

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  /// 各階段的說明與預估停留秒數。
  /// 順序對應後端 /analyze 的實際流程：上傳 → Gemini 辨識 →（有情境才有）生成情境例句 → 寫入圖鑑。
  List<AnalyzingStage> get _stages {
    final hasContext = (widget.contextDescription ?? '').trim().isNotEmpty;
    return [
      const AnalyzingStage(icon: Icons.cloud_upload_rounded, label: '正在上傳照片…', seconds: 2),
      const AnalyzingStage(icon: Icons.image_search_rounded, label: 'AI 正在辨識照片中的物品…', seconds: 9),
      if (hasContext)
        const AnalyzingStage(icon: Icons.auto_awesome_rounded, label: '正在依你的情境生成專屬例句…', seconds: 7),
      const AnalyzingStage(icon: Icons.menu_book_rounded, label: '正在整理單字並存入圖鑑…', seconds: 999),
    ];
  }

  @override
  void initState() {
    super.initState();

    // 等第一幀畫完再開始分析。
    // 若直接在 initState 內執行，失敗時會在 initState 尚未完成時就呼叫
    // showDialog，Flutter 會拋出 Localizations 相關的錯誤（未登入時必現）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAnalysis();
    });
  }

  Future<void> _startAnalysis() async {
    try {
      final userId = context.read<UserProvider>().userId;
      if (userId == null) {
        // 登入狀態失效時沒有帳號可以綁定圖鑑，直接說明原因而不是丟出技術錯誤
        _showErrorDialog('請先登入才能使用拍照辨識功能，登入後單字會自動存進你的圖鑑。');
        return;
      }
      final result = await ApiClient.analyzeImage(
        widget.imagePath,
        userId,
        customTitle: widget.customTitle,
        contextDescription: widget.contextDescription,
        assignmentId: widget.assignmentId,
      );

      if (!mounted) return;

      if (result.containsKey('result') && result['result'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SceneResultScreen(
              imagePath: widget.imagePath,
              analysisData: result['result'],
              milestone: (result['milestone'] as Map?)?.cast<String, dynamic>(),
              assignmentResult:
                  (result['assignment_result'] as Map?)?.cast<String, dynamic>(),
            ),
          ),
        );
      } else {
        _showErrorDialog(result['error']?.toString() ?? '分析失敗，請重試');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('照片分析失敗了，請確認網路連線後再試一次。');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('辨識沒有成功'),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 關閉 Dialog
              Navigator.pop(context); // 退回相機頁
            },
            child: const Text('返回重拍',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: AnalyzingStageView(
        stages: _stages,
        slowHint: 'AI 正在仔細看你的照片，請稍候…',
        slowerHint: '照片比較複雜，AI 還在努力分析中…\n請再稍等一下',
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/scene_result_screen.dart';

import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

/// 拍照辨識進行中的畫面。
///
/// 辨識全部在後端一次完成，前端無法即時得知進度，
/// 因此這裡依「後端實際的處理順序」用時間推進階段提示，
/// 讓使用者知道系統在做什麼、還在動，而不是只有一個轉圈圈。
class AnalyzingScreen extends StatefulWidget {
  final String imagePath; // 接收圖片路徑
  final String? customTitle; // 新增自訂標題
  final String? contextDescription; // 使用者描述的當下情境（選填）

  const AnalyzingScreen({
    Key? key,
    required this.imagePath,
    this.customTitle,
    this.contextDescription,
  }) : super(key: key);

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  int _stageIndex = 0;
  int _elapsedSeconds = 0;
  Timer? _stageTimer;
  Timer? _elapsedTimer;
  late final AnimationController _pulseController;

  /// 各階段的說明與預估停留秒數。
  /// 順序對應後端 /analyze 的實際流程：上傳 → Gemini 辨識 →（有情境才有）生成情境例句 → 寫入圖鑑。
  List<({IconData icon, String label, int seconds})> get _stages {
    final hasContext = (widget.contextDescription ?? '').trim().isNotEmpty;
    return [
      (icon: Icons.cloud_upload_rounded, label: '正在上傳照片…', seconds: 2),
      (icon: Icons.image_search_rounded, label: 'AI 正在辨識照片中的物品…', seconds: 9),
      if (hasContext)
        (icon: Icons.auto_awesome_rounded, label: '正在依你的情境生成專屬例句…', seconds: 7),
      (icon: Icons.menu_book_rounded, label: '正在整理單字並存入圖鑑…', seconds: 999),
    ];
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startStageTimer();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // 等第一幀畫完再開始分析。
    // 若直接在 initState 內執行，失敗時會在 initState 尚未完成時就呼叫
    // showDialog，Flutter 會拋出 Localizations 相關的錯誤（訪客未登入時必現）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAnalysis();
    });
  }

  /// 依照目前階段的預估時間，時間到就前進到下一階段（最後一個階段會停住等結果）
  void _startStageTimer() {
    final stages = _stages;
    if (_stageIndex >= stages.length - 1) return; // 已在最後階段就不再前進

    _stageTimer = Timer(Duration(seconds: stages[_stageIndex].seconds), () {
      if (!mounted) return;
      setState(() => _stageIndex++);
      _startStageTimer();
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    try {
      final userId = context.read<UserProvider>().userId;
      if (userId == null) {
        // 訪客沒有帳號可以綁定圖鑑，直接說明原因而不是丟出技術錯誤
        _showErrorDialog('請先登入才能使用拍照辨識功能，登入後單字會自動存進你的圖鑑。');
        return;
      }
      final result = await ApiClient.analyzeImage(
        widget.imagePath,
        userId,
        customTitle: widget.customTitle,
        contextDescription: widget.contextDescription,
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
    final stages = _stages;
    final currentStage = stages[_stageIndex];

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 會呼吸的圖示，讓畫面看起來是「活的」
              FadeTransition(
                opacity: Tween<double>(begin: 0.55, end: 1.0)
                    .animate(_pulseController),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLighter,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(currentStage.icon,
                      size: 66, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),

              // 目前正在做的事
              Text(
                currentStage.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 各階段的完成狀態，讓使用者知道整體進度到哪
              ...List.generate(stages.length, (i) {
                final isDone = i < _stageIndex;
                final isCurrent = i == _stageIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: isDone
                            ? const Icon(Icons.check_circle,
                                size: 20, color: AppColors.primary)
                            : isCurrent
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary)
                                : Icon(Icons.circle_outlined,
                                    size: 18, color: Colors.white24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stages[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDone
                                ? Colors.white54
                                : isCurrent
                                    ? Colors.white
                                    : Colors.white30,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // 等比較久時給個安心提示，避免使用者以為當掉
              if (_elapsedSeconds >= 15) ...[
                const SizedBox(height: 24),
                Text(
                  _elapsedSeconds >= 30
                      ? '照片比較複雜，AI 還在努力分析中…\n請再稍等一下'
                      : 'AI 正在仔細看你的照片，請稍候…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

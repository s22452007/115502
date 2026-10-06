import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

/// 分析流程中的一個階段：圖示、說明、預估停留秒數。
/// 最後一個階段給很大的秒數（例如 999），就會停在那裡等結果。
class AnalyzingStage {
  final IconData icon;
  final String label;
  final int seconds;

  const AnalyzingStage({
    required this.icon,
    required this.label,
    required this.seconds,
  });
}

/// 拍照辨識、朗讀評分這類「交給後端一次做完」的等待畫面共用的內容。
///
/// 後端處理中前端拿不到進度，所以依「後端實際的處理順序」用時間推進階段提示，
/// 讓使用者知道系統在做什麼、還在動，而不是只有一個轉圈圈。
/// 外層自行放進 Scaffold（背景用 Colors.black87）；要擋返回鍵也在外層包 PopScope。
class AnalyzingStageView extends StatefulWidget {
  final List<AnalyzingStage> stages;

  /// 等超過 15 秒時顯示的安心提示，避免使用者以為當掉
  final String slowHint;

  /// 等超過 30 秒時改顯示的提示
  final String slowerHint;

  const AnalyzingStageView({
    Key? key,
    required this.stages,
    required this.slowHint,
    required this.slowerHint,
  }) : super(key: key);

  @override
  State<AnalyzingStageView> createState() => _AnalyzingStageViewState();
}

class _AnalyzingStageViewState extends State<AnalyzingStageView>
    with SingleTickerProviderStateMixin {
  int _stageIndex = 0;
  int _elapsedSeconds = 0;
  Timer? _stageTimer;
  Timer? _elapsedTimer;
  late final AnimationController _pulseController;

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
  }

  /// 依照目前階段的預估時間，時間到就前進到下一階段（最後一個階段會停住等結果）
  void _startStageTimer() {
    final stages = widget.stages;
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

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;
    final currentStage = stages[_stageIndex];

    return SafeArea(
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
                              : const Icon(Icons.circle_outlined,
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
                _elapsedSeconds >= 30 ? widget.slowerHint : widget.slowHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

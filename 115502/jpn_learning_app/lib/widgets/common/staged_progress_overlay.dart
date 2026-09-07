import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

/// 一個階段的描述。[seconds] 是這一階段預估要停留幾秒。
class ProgressStage {
  final IconData icon;
  final String label;
  final int seconds;

  const ProgressStage({
    required this.icon,
    required this.label,
    required this.seconds,
  });
}

/// 蓋在畫面上的分階段進度提示。
///
/// 後端是一次做完才回傳，前端拿不到真實進度，所以這裡照「後端實際的處理順序」
/// 用時間推進階段，讓使用者知道系統在做什麼、還在動，而不是只有一個轉圈圈。
/// 最後一個階段會停住等結果，不會自己跑完。
///
/// 用法：放在 Stack 最上層，用 `if (isBusy) StagedProgressOverlay(...)` 控制顯示。
class StagedProgressOverlay extends StatefulWidget {
  final List<ProgressStage> stages;

  /// 等超過 [reassureAfterSeconds] 秒時顯示的安心提示，避免使用者以為當掉。
  final String? reassureText;
  final int reassureAfterSeconds;

  const StagedProgressOverlay({
    Key? key,
    required this.stages,
    this.reassureText,
    this.reassureAfterSeconds = 15,
  }) : super(key: key);

  @override
  State<StagedProgressOverlay> createState() => _StagedProgressOverlayState();
}

class _StagedProgressOverlayState extends State<StagedProgressOverlay>
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

  /// 時間到就前進到下一階段；已在最後一個階段就停住等結果。
  void _startStageTimer() {
    if (_stageIndex >= widget.stages.length - 1) return;
    _stageTimer = Timer(Duration(seconds: widget.stages[_stageIndex].seconds), () {
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

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: SafeArea(
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
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (widget.reassureText != null &&
                    _elapsedSeconds >= widget.reassureAfterSeconds) ...[
                  const SizedBox(height: 24),
                  Text(
                    widget.reassureText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

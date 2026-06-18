import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class DailyGoalCard extends StatefulWidget {
  final VoidCallback onReturnFromCamera;

  const DailyGoalCard({Key? key, required this.onReturnFromCamera})
      : super(key: key);

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard> {
  bool _isClaiming = false;
  static const _green = Color(0xFF6AA86B);

  Future<void> _claimReward() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) return;

    setState(() => _isClaiming = true);
    try {
      final result = await ApiClient.claimDailyReward(userId);
      if (!mounted) return;

      if (result.containsKey('pts_earned')) {
        final pts = (result['pts_earned'] as num).toInt();
        final bonusPhoto = (result['bonus_photo'] as num?)?.toInt() ?? 0;
        userProvider.setJPts((result['j_pts'] as num).toInt());
        userProvider.setDailyRewardClaimed(true);
        _showRewardOverlay(pts, bonusPhoto);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? '領取失敗')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showRewardOverlay(int pts, int bonusPhoto) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) =>
          _RewardOverlay(pts: pts, bonusPhoto: bonusPhoto),
      transitionBuilder: (_, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final photoDone = userProvider.dailyPhotoDone;
    final aiDone = userProvider.dailyAiDone;
    final claimed = userProvider.dailyRewardClaimed;
    final ptsMin = userProvider.dailyPtsMin;
    final ptsMax = userProvider.dailyPtsMax;
    final bonusPhoto = userProvider.dailyBonusPhoto;
    final allDone = photoDone && aiDone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                '今日學習目標',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              if (claimed) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('今日已領取',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _TaskRow(
            icon: Icons.camera_alt_outlined,
            label: '使用拍照辨識',
            done: photoDone,
          ),
          const SizedBox(height: 10),
          _TaskRow(
            icon: Icons.smart_toy_outlined,
            label: '進行 AI 對話',
            done: aiDone,
          ),
          if (!claimed) ...[
            const SizedBox(height: 16),
            if (allDone)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isClaiming ? null : _claimReward,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: _isClaiming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.redeem, size: 18),
                            SizedBox(width: 6),
                            Text('領取今日獎勵',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              )
            else
              Text(
                '完成全部任務即可領取 $ptsMin～$ptsMax J-Pts'
                '${bonusPhoto > 0 ? " + 拍照次數 +$bonusPhoto" : ""}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;

  const _TaskRow(
      {required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: done ? Colors.white : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            done ? Icons.check : icon,
            size: 16,
            color: done ? const Color(0xFF6AA86B) : Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: done ? Colors.white : Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: done ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _RewardOverlay extends StatefulWidget {
  final int pts;
  final int bonusPhoto;

  const _RewardOverlay({required this.pts, required this.bonusPhoto});

  @override
  State<_RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<_RewardOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AnimatedBuilder(
            animation: _floatAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: child,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text(
                        '+${widget.pts}',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF006D3E),
                        ),
                      ),
                      const Text(
                        'J-Pts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.bonusPhoto > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt,
                            color: Color(0xFF6AA86B), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '+${widget.bonusPhoto} 拍照次數',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006D3E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const Text(
                  '點擊任意處關閉',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
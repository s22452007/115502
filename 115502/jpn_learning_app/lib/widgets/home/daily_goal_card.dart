import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class DailyGoalCard extends StatelessWidget {
  final VoidCallback onReturnFromCamera;

  const DailyGoalCard({Key? key, required this.onReturnFromCamera})
    : super(key: key);

  static const _green = Color(0xFF6AA86B);

  void _showSelectOverlay(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => _RewardOverlay(
        userId: userId,
        onClaimed: (pts, bonusPhoto, jPts) {
          userProvider.setJPts(jPts);
          userProvider.setDailyRewardClaimed(true);
          if (bonusPhoto > 0) {
            userProvider.updatePhotoUsage(
              extraCount: userProvider.photoExtraCount + bonusPhoto,
            );
          }
        },
      ),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
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
          ),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (claimed) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '今日已領取',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
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
                  onPressed: () => _showSelectOverlay(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.redeem, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '領取今日獎勵',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                '完成全部任務即可領取 $ptsMin～$ptsMax J-Pts'
                '${bonusPhoto > 0 ? " + 拍照次數 +$bonusPhoto" : ""}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
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

  const _TaskRow({required this.icon, required this.label, required this.done});

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

// ==========================================
// 三選一禮物盒 Overlay
// ==========================================

class _RewardOverlay extends StatefulWidget {
  final int userId;
  final void Function(int pts, int bonusPhoto, int jPts) onClaimed;

  const _RewardOverlay({required this.userId, required this.onClaimed});

  @override
  State<_RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<_RewardOverlay>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  bool _revealed = false;
  bool _loading = false;
  int _pts = 0;
  int _bonusPhoto = 0;

  late AnimationController _revealController;
  late Animation<double> _revealScale;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _revealScale =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.25), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 30),
        ]).animate(
          CurvedAnimation(parent: _revealController, curve: Curves.easeOut),
        );
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _selectBox(int index) async {
    if (_selectedIndex != null || _loading) return;
    setState(() {
      _selectedIndex = index;
      _loading = true;
    });

    final result = await ApiClient.claimDailyReward(widget.userId);
    if (!mounted) return;

    if (result.containsKey('pts_earned')) {
      _pts = (result['pts_earned'] as num).toInt();
      _bonusPhoto = (result['bonus_photo'] as num?)?.toInt() ?? 0;
      final jPts = (result['j_pts'] as num).toInt();
      widget.onClaimed(_pts, _bonusPhoto, jPts);
      setState(() => _loading = false);
      await _revealController.forward();
      if (!mounted) return;
      setState(() => _revealed = true);
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      _confettiController.play();
    } else {
      if (mounted) {
        setState(() {
          _selectedIndex = null;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? '領取失敗，請稍後再試')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 3.14159 / 2,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
            shouldLoop: false,
            colors: const [
              Colors.amber,
              Colors.white,
              Color(0xFF6AA86B),
              Colors.orangeAccent,
            ],
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _revealed ? '恭喜！' : '選一個禮物盒！',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _revealed ? '' : '今日獎勵就藏在其中一個',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0, 1, 2].map((i) => _buildBox(i)).toList(),
                ),
                const SizedBox(height: 36),
                if (_revealed)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Text(
                        '返回',
                        style: TextStyle(
                          color: Color(0xFF006D3E),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                if (_bonusPhoto > 0 && _revealed) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+$_bonusPhoto 拍照次數',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBox(int index) {
    final isSelected = _selectedIndex == index;
    final isOther = _selectedIndex != null && !isSelected;
    final boxSize = isSelected ? 120.0 : 95.0;

    return GestureDetector(
      onTap: _selectedIndex == null ? () => _selectBox(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          color: isOther ? Colors.white.withValues(alpha: 0.2) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Center(child: _buildBoxContent(isSelected, isOther)),
      ),
    );
  }

  Widget _buildBoxContent(bool isSelected, bool isOther) {
    if (isOther) {
      return Text(
        '❓',
        style: TextStyle(
          fontSize: 36,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      );
    }

    if (isSelected && _loading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF006D3E),
        ),
      );
    }

    if (isSelected && !_loading) {
      return AnimatedBuilder(
        animation: _revealScale,
        builder: (_, child) =>
            Transform.scale(scale: _revealScale.value, child: child),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 28)),
            Text(
              '+$_pts',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF006D3E),
              ),
            ),
            const Text(
              'J-Pts',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return const Text('🎁', style: TextStyle(fontSize: 46));
  }
}

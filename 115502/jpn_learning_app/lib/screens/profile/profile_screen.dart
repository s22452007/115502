import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/profile/photo_folder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Icon(Icons.menu, color: Colors.white),
        title: Icon(Icons.camera_alt, color: Colors.white),
        centerTitle: true,
        actions: [Icon(Icons.person_outline, color: Colors.white), const SizedBox(width: 12)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 使用者頭像與等級
            Row(children: [
              CircleAvatar(radius: 36, backgroundColor: AppColors.primaryLighter,
                  child: Icon(Icons.person, color: AppColors.primary, size: 40)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Lv.3  Yu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                SizedBox(width: 150, child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.6, backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary), minHeight: 10,
                  ),
                )),
              ]),
            ]),
            const SizedBox(height: 24),
            // 能力雷達圖區
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('能力', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(size: const Size(180, 180), painter: _SimpleRadarPainter()),
                      const Positioned(top: 4, child: Text('Listening', style: TextStyle(fontSize: 11, color: AppColors.textGrey))),
                      const Positioned(right: 8, bottom: 40, child: Text('換一個', style: TextStyle(fontSize: 11, color: AppColors.textGrey))),
                      const Positioned(bottom: 4, right: 40, child: Text('Reading', style: TextStyle(fontSize: 11, color: AppColors.textGrey))),
                      const Positioned(bottom: 4, left: 20, child: Text('Writing', style: TextStyle(fontSize: 11, color: AppColors.textGrey))),
                      const Positioned(left: 8, bottom: 40, child: Text('Culture', style: TextStyle(fontSize: 11, color: AppColors.textGrey))),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 成就
            const Text('成就', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AchievementBadge(icon: '🍜', label: '拉麵大師', unlocked: true),
                _AchievementBadge(icon: '☕', label: '咖啡廳大師', unlocked: true),
                _AchievementBadge(icon: '🏯', label: '文化', unlocked: true),
                _AchievementBadge(icon: '🔒', label: '?', unlocked: false),
                _AchievementBadge(icon: '🔒', label: '?', unlocked: false),
                _AchievementBadge(icon: '🔒', label: '?', unlocked: false),
              ],
            ),
            const SizedBox(height: 20),
            // 收藏夾
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('收藏夾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoFolderScreen())),
                  child: Text('查看全部', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(currentIndex: 4, onTap: (_) {}),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String icon, label;
  final bool unlocked;
  const _AchievementBadge({required this.icon, required this.label, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: unlocked ? AppColors.primaryLighter : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(unlocked ? icon : '🔒', style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: unlocked ? AppColors.textDark : AppColors.textGrey)),
      ],
    );
  }
}

class _SimpleRadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = AppColors.primaryLighter..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = 2;
    final gridPaint = Paint()..color = Colors.grey.shade300..style = PaintingStyle.stroke..strokeWidth = 1;

    final r = size.width / 2.5;
    for (double pct in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final angle = (i * 72 - 90) * 3.14159 / 180;
        final x = center.dx + r * pct * _cos5(i);
        final y = center.dy + r * pct * _sin5(i);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, pct == 1.0 ? gridPaint : gridPaint);
    }
    final path = Path();
    final values = [0.9, 0.5, 0.7, 0.6, 0.4];
    for (int i = 0; i < 5; i++) {
      final x = center.dx + r * values[i] * _cos5(i);
      final y = center.dy + r * values[i] * _sin5(i);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  double _cos5(int i) => [0, 0.95, 0.59, -0.59, -0.95][i].toDouble();
  double _sin5(int i) => [-1, -0.31, 0.81, 0.81, -0.31][i].toDouble();

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

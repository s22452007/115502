import 'package:flutter/material.dart';
import 'package:jpn_learning_app_new/utils/constants.dart';
import 'package:jpn_learning_app_new/screens/home/home_screen.dart';

class TestResultScreen extends StatelessWidget {
  const TestResultScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Text('測驗完成', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('S', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              const SizedBox(height: 16),
              const Text('Score: 95/100', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              _RadarChartPlaceholder(),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (r) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('結束探索', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  side: BorderSide(color: AppColors.primary),
                ),
                child: const Text('繼續探索', style: TextStyle(color: AppColors.primary, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarChartPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final labels = ['Listening', 'Speaking', 'Reading', 'Writing', 'Culture'];
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(200, 200), painter: _RadarPainter()),
          ...List.generate(5, (i) {
            final angle = (i * 72 - 90) * 3.14159 / 180;
            final r = 110.0;
            return Positioned(
              left: 100 + r * 0.85 * (i == 0 ? 0 : i == 1 ? 0.95 : i == 2 ? 0.59 : i == 3 ? -0.59 : -0.95),
              top: 100 + r * 0.85 * (i == 0 ? -1 : i == 1 ? -0.31 : i == 2 ? 0.81 : i == 3 ? 0.81 : -0.31),
              child: Text(labels[i], style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            );
          }),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLighter
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2.5;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * 3.14159 / 180;
      final x = center.dx + r * 0.8 * (i == 0 ? 0 : i == 1 ? 0.95 : i == 2 ? 0.59 : i == 3 ? -0.59 : -0.95);
      final y = center.dy + r * 0.8 * (i == 0 ? -1 : i == 1 ? -0.31 : i == 2 ? 0.81 : i == 3 ? 0.81 : -0.31);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

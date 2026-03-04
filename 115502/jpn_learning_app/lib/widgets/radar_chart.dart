import 'package:flutter/material.dart';
import 'dart:math' show pi, cos, sin;

class RadarChartWidget extends StatelessWidget {
  // 接收各項能力的分數 (0.0 ~ 1.0)
  final List<double> scores;
  
  const RadarChartWidget({
    Key? key, 
    this.scores = const [0.8, 0.6, 0.9, 0.7, 0.5], // 預設假資料
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 雷達圖本體
          CustomPaint(
            size: const Size(160, 160),
            painter: _RadarChartPainter(scores),
          ),
          // 標籤文字 (絕對定位在周圍)
          const Positioned(top: -10, child: Text('Listening', style: TextStyle(fontSize: 12))),
          const Positioned(right: -10, top: 60, child: Text('Speaking', style: TextStyle(fontSize: 12))),
          const Positioned(right: 10, bottom: -10, child: Text('Reading', style: TextStyle(fontSize: 12))),
          const Positioned(left: 10, bottom: -10, child: Text('Writing', style: TextStyle(fontSize: 12))),
          const Positioned(left: -10, top: 60, child: Text('Culture', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<double> scores;
  _RadarChartPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sides = 5;
    final angle = (2 * pi) / sides;

    // 畫筆設定：底圖外框
    final paintLine = Paint()
      ..color = Colors.green.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 畫筆設定：能力值填充
    final paintFill = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // 畫蜘蛛網底圖 (3層)
    for (int step = 1; step <= 3; step++) {
      final path = Path();
      final currentRadius = radius * (step / 3);
      for (int i = 0; i < sides; i++) {
        double x = center.dx + currentRadius * cos(angle * i - pi / 2);
        double y = center.dy + currentRadius * sin(angle * i - pi / 2);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paintLine);
    }

    // 畫能力數值範圍
    final valuePath = Path();
    for (int i = 0; i < sides; i++) {
      // 確保傳入的分數不超過 1.0，避免超出圖表
      double safeScore = scores[i] > 1.0 ? 1.0 : scores[i];
      double x = center.dx + (radius * safeScore) * cos(angle * i - pi / 2);
      double y = center.dy + (radius * safeScore) * sin(angle * i - pi / 2);
      i == 0 ? valuePath.moveTo(x, y) : valuePath.lineTo(x, y);
    }
    valuePath.close();
    canvas.drawPath(valuePath, paintFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
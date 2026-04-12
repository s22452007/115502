import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/radar_chart.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

class ProfileRadarSection extends StatelessWidget {
  final bool isGuest;
  final List<double> radarValues;

  const ProfileRadarSection({
    Key? key,
    required this.isGuest,
    required this.radarValues,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFFF1F8E9);
    final textColor = const Color(0xFF333333);
    final primaryGreen = const Color.fromARGB(255, 74, 124, 89);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('能力', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: RadarChartPainter(color: primaryGreen, values: radarValues),
                  ),
                ),
              ),
              if (isGuest)
                Container(
                  width: double.infinity,
                  height: 220,
                  color: Colors.white.withOpacity(0.7),
                  child: Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('登入查看能力分析', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
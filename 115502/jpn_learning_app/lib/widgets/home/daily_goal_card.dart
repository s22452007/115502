/// 每日學習目標卡片 Widget
/// 顯示今日拍照次數使用情況
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';

/// 每日目標卡片組件
/// 顯示今日拍照次數進度
class DailyGoalCard extends StatelessWidget {
  final VoidCallback onReturnFromCamera;

  const DailyGoalCard({
    Key? key,
    required this.onReturnFromCamera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final goalGreen = const Color(0xFF6AA86B);

    final photoCountToday = userProvider.photoCountToday;
    final photoDailyLimit = userProvider.photoDailyLimit;
    final photoExtraCount = userProvider.photoExtraCount;

    // 計算有效剩餘次數
    final dailyRemaining = (photoDailyLimit - photoCountToday).clamp(0, photoDailyLimit);
    final effectiveRemaining = dailyRemaining + photoExtraCount;
    final progress = (photoCountToday / photoDailyLimit).clamp(0.0, 1.0);

    // 進度條顏色：綠→橘→紅
    final progressColor = effectiveRemaining <= 0
        ? Colors.red.shade200
        : effectiveRemaining == 1
            ? Colors.orange.shade200
            : Colors.white;

    final extraText = photoExtraCount > 0 ? ' 額外$photoExtraCount次' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: goalGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: goalGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '今日拍照使用情況',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '進度：$photoCountToday / $photoDailyLimit 次$extraText',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()))
                    .then((_) {
                      onReturnFromCamera();
                    });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: goalGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  elevation: 0,
                ),
                child: const Row(
                  children: [
                    Text('開啟相機', style: TextStyle(fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward_outlined, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
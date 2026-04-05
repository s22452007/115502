/// 每日學習目標卡片 Widget
/// 負責顯示用戶當日的學習目標進度，包括拍照場景數量的進度條和開啟相機按鈕
/// 這個卡片會根據 UserProvider 的 dailyScans 狀態動態更新進度
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';

/// 每日目標卡片組件
/// 顯示「探索3個新場景」的進度，並提供快速開啟相機的功能
class DailyGoalCard extends StatelessWidget {
  /// 建構子
  /// 不需要額外參數，因為所有必要資料都從 UserProvider 獲取
  const DailyGoalCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final goalGreen = const Color(0xFF6AA86B);

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
          const Row(
            children: [
              Icon(Icons.track_changes, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('探索3個新場景', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (userProvider.dailyScans / 3.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('進度 : ${userProvider.dailyScans}/3', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
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
/// 付費功能鎖定覆蓋層 Widget
/// 負責在未登入用戶的付費功能上顯示鎖定效果和登入提示
/// 使用模糊背景和鎖定圖示來阻止用戶互動，並提供登入按鈕
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

/// 付費功能鎖定覆蓋組件
/// 在需要登入的功能上顯示半透明模糊覆蓋，提示用戶登入以解鎖功能
class PremiumLockedOverlay extends StatelessWidget {
  /// 要被覆蓋的子 Widget
  final Widget child;

  /// 顯示的鎖定訊息文字
  final String message;

  /// 建構子
  /// @param child 要被鎖定的 Widget
  /// @param message 顯示的鎖定提示訊息
  const PremiumLockedOverlay({Key? key, required this.child, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final goalGreen = const Color(0xFF6AA86B);

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.35, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: Container(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: goalGreen, borderRadius: BorderRadius.circular(20)),
                  child: const Text('去登入', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
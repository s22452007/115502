import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

class PremiumLockedOverlay extends StatelessWidget {
  final Widget child;
  final String message;

  const PremiumLockedOverlay({Key? key, required this.child, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {

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
                  decoration: BoxDecoration(color: const Color(0xFF6AA86B), borderRadius: BorderRadius.circular(20)),
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
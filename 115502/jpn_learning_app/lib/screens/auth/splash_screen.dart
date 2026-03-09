import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 設定 2 秒後自動跳轉到引導頁 (OnboardingScreen)
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 這裡已經換成你的 Logo 圖片了！
            Image.asset(
              'images/nelogo.bmp', // 確保檔名是小寫
              width: 150, // 可以自行調整 Logo 大小
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            // App 的名稱標題
            const Text(
              'snap to learn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

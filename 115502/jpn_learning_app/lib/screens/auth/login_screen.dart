import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 保留了這個跳轉頁面的設定
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // 這是你之後要換成自己 Logo 的地方 (目前先保留相機圖示)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 48),

              // Google 登入按鈕
              OutlinedButton.icon(
                onPressed: () {
                  print('觸發 Google 登入邏輯');
                },
                icon: const Icon(
                  Icons.g_mobiledata,
                  size: 36,
                  color: Colors.black87,
                ),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Apple 登入按鈕
              OutlinedButton.icon(
                onPressed: () {
                  print('觸發 Apple 登入邏輯');
                },
                icon: const Icon(Icons.apple, size: 28, color: Colors.black87),
                label: const Text(
                  'Sign in with Apple',
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              const Spacer(),

              // 訪客登入按鈕 (已幫你設定好跳轉功能！)
              TextButton(
                onPressed: () {
                  // 點擊後會直接跳到難易度選擇畫面
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LevelSelectScreen(),
                    ),
                  );
                },
                child: const Text(
                  '訪客登入 (Continue as Guest)',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

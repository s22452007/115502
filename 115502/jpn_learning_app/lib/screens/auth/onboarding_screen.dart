import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          // 右上角 Skip 鍵
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          const SizedBox(width: 16.0),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 核心結構：PageView (圖片與文字會跟著這層一起絲滑連動) [cite: 7, 8, 9]
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildPageContent(
                    icon: Icons.camera_alt,
                    title: 'snap to learn',
                  ),
                  _buildPageContent(icon: Icons.menu_book, title: '輕鬆學習日文'),
                  _buildPageContent(icon: Icons.translate, title: '馬上開始你的旅程'),
                ],
              ),
            ),

            // 🌟 升級點 1：會像水滴般平滑變形的狀態點點 (AnimatedContainer) [cite: 11, 12, 13]
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300), // 點點變形的動畫時間
                  curve: Curves.easeOutCubic, // 點點變形的曲線
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: _currentPage == index ? 24.0 : 8.0, // 當前頁面的點會拉長
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.primaryLighter,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 底部主按鈕
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 20.0,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    if (_currentPage < 2) {
                      // 🌟 升級點 2：使用 easeInOutCubic，營造電影級的柔和起步與緩停 [cite: 17, 18]
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500), 
                        curve: Curves.easeInOutCubic, 
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  child: Text(
                    _currentPage == 2 ? '開始使用' : '下一頁',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // 建立每一頁圖片與內容的小工具 (完全保留您的原始排版) [cite: 23, 24, 25]
  Widget _buildPageContent({required IconData icon, required String title}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.primaryLighter,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Icon(icon, size: 80, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.textGrey,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
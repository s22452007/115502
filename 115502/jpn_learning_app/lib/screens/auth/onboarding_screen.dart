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

  final List<Map<String, dynamic>> _pagesData = [
    {'icon': Icons.camera_alt, 'title': 'snap to learn'},
    {'icon': Icons.menu_book, 'title': '輕鬆學習日文'},
    {'icon': Icons.translate, 'title': '馬上開始你的旅程'},
  ];

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _flatCanvasColor,
      appBar: AppBar(
        backgroundColor: _flatCanvasColor,
        elevation: 0,
        actions: [
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
              // 🌟 Commit 2：淡化右上角字體，不搶戲
              style: TextStyle(
                color: Colors.black38, 
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 20.0),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pagesData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPageContent(
                    icon: _pagesData[index]['icon'] as IconData,
                    title: _pagesData[index]['title'] as String,
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pagesData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: _currentPage == index ? 24.0 : 8.0,
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
                    if (_currentPage < _pagesData.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutQuart,
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  child: Text(
                    _currentPage == _pagesData.length - 1 ? '開始使用' : '下一頁',
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

  Widget _buildPageContent({required IconData icon, required String title}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 🌟 Commit 2 核心：改為純白、無陰影大圓角卡片
        Container(
          width: 200, 
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(40), 
          ),
          child: Icon(icon, size: 90, color: AppColors.primary),
        ),
        const SizedBox(height: 40),
        // 🌟 Commit 2 核心：加粗標題並使用深色系
        Text(
          title,
          style: const TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.w900, 
            color: Color(0xFF2C3E50), 
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
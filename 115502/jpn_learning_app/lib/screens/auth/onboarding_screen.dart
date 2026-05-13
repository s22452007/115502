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

  // 整理頁面資料
  final List<Map<String, dynamic>> _pagesData = [
    {'icon': Icons.camera_alt, 'title': 'snap to learn'},
    {'icon': Icons.menu_book, 'title': '輕鬆學習日文'},
    {'icon': Icons.translate, 'title': '馬上開始你的旅程'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
            // 純粹的滑動 PageView
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

            // 底部狀態點點 (滑順水滴變形特效)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pagesData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart, // 點點也跟隨立刻反應的曲線
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
                    if (_currentPage < _pagesData.length - 1) {
                      // ⚡ 終極手感解法：起步立刻彈出零遲疑，結尾像絲綢般滑行
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
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

  // 建立每一頁內容的小工具
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
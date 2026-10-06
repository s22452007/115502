import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/edu_login_screen.dart';
import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
// 🌟 確保正確引入剛剛建立的 IntroScreen
import 'package:jpn_learning_app/screens/intro_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                '沉浸式日語對話學習平台',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '歡迎光臨 Snap to Learn',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 40),

              // 1. 一般版卡片
              Expanded(
                child: _buildRoleCard(
                  context,
                  title: '一般自主學習',
                  description: '隨時隨地展開 AI 情境對話\n提升日語口說與聽力能力',
                  icon: Icons.person,
                  themeColor: AppColors.primary,
                  onIntroTap: () {
                    // 👉 跳轉到新的 IntroScreen (一般版)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IntroScreen(isEdu: false),
                      ),
                    );
                  },
                  onLoginTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SplashScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 2. 教育版卡片
              Expanded(
                child: _buildRoleCard(
                  context,
                  title: '校園教育版',
                  description: '專為學校課程設計的練習任務\n結合教師後台與學習進度追蹤',
                  icon: Icons.school,
                  themeColor: const Color(0xFF4A90E2),
                  onIntroTap: () {
                    // 👉 跳轉到新的 IntroScreen (教育版)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IntroScreen(isEdu: true),
                      ),
                    );
                  },
                  onLoginTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EduLoginScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 角色卡片：上方圖示與說明撐滿卡片，下方並排「瀏覽介紹／登入」按鈕
  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color themeColor,
    required VoidCallback onIntroTap,
    required VoidCallback onLoginTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // 使用 ClipRRect 裁切，確保按鈕的水波紋效果不會超出圓角邊界
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 上方：圖示、標題與描述，置中填滿剩餘高度；矮螢幕時整塊等比縮小避免溢出
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: themeColor, size: 34),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 下方：按鈕列
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  // 瀏覽介紹按鈕
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onIntroTap,
                        child: Center(
                          child: Text(
                            '瀏覽介紹',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeColor.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 垂直分割線
                  VerticalDivider(
                    width: 1.5,
                    thickness: 1.5,
                    color: Colors.grey.shade200,
                  ),
                  // 登入按鈕
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onLoginTap,
                        child: Center(
                          child: Text(
                            '登入',
                            style: TextStyle(
                              fontSize: 15,
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

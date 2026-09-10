import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/edu_login_screen.dart';
import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
// 🌟 確保這裡有引入你剛剛新建立的 IntroScreen
import 'package:jpn_learning_app/screens/intro_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // 類似 Zuvio 的淡藍灰背景
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
              _buildRoleCard(
                context,
                title: '一般自主學習',
                description: '隨時隨地展開 AI 情境對話\n提升日語口說與聽力能力',
                icon: Icons.person,
                themeColor: AppColors.primary,
                onIntroTap: () {
                  // 🌟 這裡已經改成跳轉到新的 IntroScreen
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
              const SizedBox(height: 24),

              // 2. 教育版卡片
              _buildRoleCard(
                context,
                title: '校園教育版',
                description: '專為學校課程設計的練習任務\n結合教師後台與學習進度追蹤',
                icon: Icons.school,
                themeColor: const Color(0xFF4A90E2),
                onIntroTap: () {
                  // 🌟 這裡已經改成跳轉到新的 IntroScreen
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
            ],
          ),
        ),
      ),
    );
  }

  // 獨立的 Zuvio 風格卡片元件
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左側：顏色圖示區塊
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: themeColor, size: 32),
              ),
            ),

            // 中間：標題與描述
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 右側：分割線與按鈕區域
            Container(
              width: 80,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onIntroTap,
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
                        child: Center(
                          child: Text(
                            '瀏覽介紹',
                            style: TextStyle(
                              fontSize: 13,
                              color: themeColor.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200, thickness: 1.5),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onLoginTap,
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                        child: Center(
                          child: Text(
                            '登入',
                            style: TextStyle(
                              fontSize: 14,
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
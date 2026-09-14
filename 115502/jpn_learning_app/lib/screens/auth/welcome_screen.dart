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
              const SizedBox(height: 24),

              // 2. 教育版卡片
              _buildRoleCard(
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
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 獨立的 Zuvio 風格卡片元件 (終極排版修復版：Stack 疊加防溢出)
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
      // 使用 ClipRRect 裁切，確保按鈕的水波紋效果不會超出圓角邊界
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        // 放棄 IntrinsicHeight，改用 Stack 讓高度完全由左側文字決定
        child: Stack(
          children: [
            // 底部層：主要內容與高度支撐
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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

                // 預留右側按鈕的寬度 80，避免文字疊到按鈕下方
                const SizedBox(width: 80),
              ],
            ),

            // 上面層：右側按鈕區域，利用 Positioned 自動填滿卡片的上下高度
            Positioned(
              right: 0,
              top: 0,
              bottom: 0, 
              width: 80,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                  ),
                ),
                child: Column(
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
                                fontSize: 13,
                                color: themeColor.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 水平分割線
                    Divider(height: 1, color: Colors.grey.shade200, thickness: 1.5),
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
            ),
          ],
        ),
      ),
    );
  }
}
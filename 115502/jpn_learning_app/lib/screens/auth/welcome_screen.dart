import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/edu_login_screen.dart';
import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  // 🌟 1. 新增：底部介紹彈窗邏輯
  void _showIntroBottomSheet(BuildContext context, {required bool isEdu}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部小把手
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // 標題與 Icon
              Row(
                children: [
                  Icon(
                    isEdu ? Icons.school_rounded : Icons.person_rounded,
                    color: isEdu ? const Color(0xFF4A90E2) : AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdu ? '校園教育版介紹' : '一般自主學習介紹',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 特色列表 (根據版本替換內容)
              _buildFeatureItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: isEdu ? '專屬課程對話' : 'AI 情境角色扮演',
                desc: isEdu ? '配合學校進度，與 AI 進行指定場景的對話練習。' : '超過 50 種生活情境，隨時隨地與 AI 開口說日文。',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.analytics_outlined,
                title: isEdu ? '教師後台連動' : 'AI 嚴格發音批改',
                desc: isEdu ? '練習成績自動同步至教師後台，輕鬆追蹤學習成效。' : '精準抓出發音與文法錯誤，提供完美句子建議。',
              ),
              const SizedBox(height: 32),
              // 確認按鈕
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEdu ? const Color(0xFF4A90E2) : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '了解，馬上登入',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20), // 預留底部安全距離
            ],
          ),
        );
      },
    );
  }

  // 🌟 2. 新增：組合介紹項目的小元件
  Widget _buildFeatureItem({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[800]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

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
                  // 👉 呼叫一般版介紹彈窗
                  _showIntroBottomSheet(context, isEdu: false);
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
                themeColor: const Color(0xFF4A90E2), // 專屬教育版的藍色
                onIntroTap: () {
                  // 👉 呼叫教育版介紹彈窗
                  _showIntroBottomSheet(context, isEdu: true);
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
        // 讓右側的垂直分割線能自動對齊高度
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
                      maxLines: 2, // 🌟 解決黑黃線條的核心：限制最多兩行
                      overflow: TextOverflow.ellipsis, // 🌟 超出時顯示點點點
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
                  // 瀏覽介紹按鈕
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
                  // 水平分割線
                  Divider(height: 1, color: Colors.grey.shade200, thickness: 1.5),
                  // 登入按鈕
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
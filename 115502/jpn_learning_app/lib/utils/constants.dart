import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF4A7C59);
  static const Color primaryLight = Color(0xFF7BAE8A);
  static const Color primaryLighter = Color(0xFFD4E8DA);
  static const Color background = Color(0xFFF5F5F0);
  static const Color cardYellow = Color(0xFFF5EEC8);
  static const Color cardGreen = Color(0xFFE8F5E9);
  static const Color textDark = Color(0xFF2D3B2D);
  static const Color textGrey = Color(0xFF7A8C7A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gold = Color(0xFFD4E8DA);

  // --- 🌟 新增：首頁與解鎖卡片專用色 ---
  static const Color accentGreen = Color(0xFF6AA86B); // 首頁目標卡片、去登入按鈕
  static const Color cardPurple = Color(0xFF856DA0); // 一蘭拉麵卡片 Icon 底色
  static const Color cardBlue = Color(0xFF85B8D6); // 新宿車站卡片 Icon 底色
  static const Color textBlack = Color(0xFF333333); // 首頁深黑標題文字
  static const Color textSub = Color(0xFF888888); // 首頁淺灰副標題文字
}

class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textDark,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textGrey,
  );
  static const TextStyle japanese = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
}

const String baseUrl = 'http://10.0.2.2:5000/api';

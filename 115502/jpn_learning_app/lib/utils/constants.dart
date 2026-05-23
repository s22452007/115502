import 'package:flutter/material.dart';

class AppColors {
  // 主色體系
  static const Color primary = Color(0xFF4E8B4C);      // 主綠色（按鈕、強調）
  static const Color primaryLight = Color(0xFFEAF4EA); // 淡綠色（背景）
  static const Color secondary = Color(0xFFC6B13B);    // 金色（次要、標籤）

  // 文字色
  static const Color textDark = Color(0xFF333333);     // 深色文字
  static const Color textGrey = Color(0xFF777777);     // 灰色文字
  static const Color textSubtle = Color(0xFF888888);   // 淡灰色文字

  // 背景色
  static const Color background = Color(0xFFF5F5F0);   // 頁面背景
  static const Color cardBackground = Color(0xFFFFFFFF); // 卡片背景
  static const Color lightBg = Color(0xFFF8F9FA);      // 淡白背景

  // 卡片色
  static const Color cardGreen = Color(0xFFE8F5E9);    // 綠色卡片
  static const Color cardGold = Color(0xFFFFF8E1);     // 金色卡片
  static const Color cardBeige = Color(0xFFFCF6EA);    // 米色卡片

  // 警告和狀態色
  static const Color warning = Color(0xFFFFC107);      // 警告色（橘色）
  static const Color error = Color(0xFFFF6B6B);        // 錯誤色（紅色）
  static const Color success = Color(0xFF4CAF50);      // 成功色（綠色）

  // 邊框色
  static const Color borderLight = Color(0xFFE0E0E0);  // 淡邊框
  static const Color borderGreen = Color(0xFFA9C5A8); // 綠色邊框

  // 舊色彩（相容性）
  static const Color primaryLight2 = Color(0xFF7BAE8A);
  static const Color primaryLighter = Color(0xFFD4E8DA);
  static const Color cardYellow = Color(0xFFF5EEC8);
  static const Color gold = Color(0xFF88741F);
  static const Color accentGreen = Color(0xFF6AA86B);
  static const Color cardPurple = Color(0xFF856DA0);
  static const Color cardBlue = Color(0xFF85B8D6);
  static const Color textBlack = Color(0xFF333333);
  static const Color textSub = Color(0xFF888888);
  static const Color white = Color(0xFFFFFFFF);
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

// 日期格式化工具函式
String formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

const String baseUrl = 'http://10.0.2.2:5000/api';

const Map<String, String> transactionTypeLabels = {
  'purchase': '購買點數',
  'spend': '消費點數',
  'reward': '獎勵點數',
  'subscription_grant': '訂閱贈點',
  'deposit': '押金扣除',
  'deposit_refund': '押金退還',
  'group_reward': '小組達成獎勵',
};

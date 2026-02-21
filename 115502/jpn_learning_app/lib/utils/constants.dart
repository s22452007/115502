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
  static const Color gold = Color(0xFFD4AF37);
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

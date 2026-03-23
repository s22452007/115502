import 'package:flutter/material.dart';

class BadgeModel {
  final String id;          // 徽章唯一 ID
  final String title;       // 徽章名稱
  final String description; // 已解鎖的取得說明
  final String lockedHint;  // 未解鎖的提示
  final IconData icon;      // 徽章圖示 
  bool isUnlocked;          // 是否已解鎖
  String? unlockedDate;     // 解鎖日期 (可選)

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.lockedHint,
    required this.icon,
    this.isUnlocked = false,
    this.unlockedDate,
  });
}
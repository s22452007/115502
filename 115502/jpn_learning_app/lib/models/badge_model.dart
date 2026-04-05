import 'package:flutter/material.dart';

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<int> milestones; // 5 個等級的門檻數字
  final List<String>? levelLabels; // 自訂等級名稱 (給程度認證用)

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.milestones,
    this.levelLabels,
  });
}
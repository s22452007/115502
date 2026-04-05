import 'package:flutter/material.dart';

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String lockedHint;
  final IconData icon;
  final String category; // 這是為了新版分類 UI 加的

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.lockedHint,
    required this.icon,
    this.category = '未分類', // 給個預設值，不怕報錯
  });
}
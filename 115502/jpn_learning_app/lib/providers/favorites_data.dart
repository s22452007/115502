// lib/providers/favorites_data.dart
import 'package:flutter/material.dart';

// --- 先定義一個「場景」的格式 (Data Model) ---
class ScenarioItem {
  final String title;
  final String date;
  final String? image; // 圖片是選填的
  final Map<String, String> vocabulary; // {'日文': '中文'}

  ScenarioItem({
    required this.title,
    required this.date,
    this.image,
    required this.vocabulary,
  });
}

// ==========================================
// 🌟 這就是你的「全域單字資料庫」！
// ==========================================
class FavoritesDataProvider {
  // 把你的資料統整在這裡，要修改、新增只要改這裡！
  static final List<ScenarioItem> allFavorites = [
    // 1. 一蘭拉麵店
    ScenarioItem(
      title: '一蘭拉麵店',
      date: '2023.10.27',
      // 圖片我先註解掉，如果你有圖片可以打開
      // image: 'images/japan02.bmp',
      vocabulary: {'ラーメン': '拉麵', 'とんこつ': '豚骨', '替玉': '加麵', 'いらっしゃいませ': '歡迎光臨'},
    ),
    // 2. 新宿車站
    ScenarioItem(
      title: '新宿車站',
      date: '2023.10.28',
      vocabulary: {'駅': '車站', '電車': '電車', '乗り換え': '轉乘', 'きっぷ': '車票'},
    ),
    // 3. (新增的) 淺草寺
    ScenarioItem(
      title: '淺草寺',
      date: '2023.10.29',
      vocabulary: {'お寺': '寺廟', 'おみくじ': '籤', '雷門': '雷門'},
    ),
  ];
}

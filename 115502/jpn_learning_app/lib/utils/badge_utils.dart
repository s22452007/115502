/// 徽章工具類別
/// 負責處理所有與徽章進度、等級計算、主題樣式相關的共用邏輯
/// 這個類別提供靜態方法，讓其他畫面也能輕鬆使用徽章相關功能
import 'package:flutter/material.dart';

class BadgeUtils {
  /// 徽章里程碑定義
  /// 每個徽章類型對應的進度門檻，用於計算等級
  static const Map<String, List<int>> badgeMilestones = {
    'level_01': [1, 2, 3, 4, 5],           // 程度認證：1,2,3,4,5 級
    'vocab_01': [10, 50, 100, 300, 500],   // 單字大富翁：10,50,100,300,500 個單字
    'streak_01': [3, 7, 14, 30, 60],       // 學習火種：3,7,14,30,60 天連續學習
    'marathon_01': [5, 15, 50, 100, 200],  // 學習馬拉松：5,15,50,100,200 次學習
    'camera_01': [10, 50, 200, 500, 1000], // 快門獵人：10,50,200,500,1000 次拍照
  };

  /// 計算徽章等級
  /// 根據當前進度值和里程碑列表，計算出對應的等級
  /// @param progress 當前進度值
  /// @param milestones 該徽章的里程碑列表
  /// @return 等級 (1-5)，如果沒有達到任何里程碑則返回 0
  static int calculateLevel(int progress, List<int> milestones) {
    int level = 0;
    for (int i = 0; i < milestones.length; i++) {
      if (progress >= milestones[i]) level = i + 1;
      else break;
    }
    return level;
  }

  /// 獲取等級主題樣式
  /// 根據等級返回對應的顯示名稱、顏色和是否使用漸層效果
  /// @param level 等級 (1-5)
  /// @return 包含 'name', 'color', 'isGradient' 的地圖
  static Map<String, dynamic> getLevelTheme(int level) {
    switch (level) {
      case 5: return {'name': '白金級', 'color': Colors.purpleAccent, 'isGradient': true};
      case 4: return {'name': '金牌', 'color': Colors.amber[400]!, 'isGradient': false};
      case 3: return {'name': '銀牌', 'color': Colors.blueGrey[300]!, 'isGradient': false};
      case 2: return {'name': '銅牌', 'color': Colors.orange[700]!, 'isGradient': false};
      case 1: return {'name': '初階', 'color': Colors.brown[400]!, 'isGradient': false};
      default: return {'name': '未解鎖', 'color': Colors.grey[400]!, 'isGradient': false};
    }
  }
}
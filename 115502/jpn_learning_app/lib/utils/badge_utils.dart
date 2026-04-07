/// 徽章工具類別
/// 負責處理所有與徽章進度、等級計算、主題樣式相關的共用邏輯
/// 這個類別提供靜態方法，讓其他畫面也能輕鬆使用徽章相關功能
import 'package:flutter/material.dart';

class BadgeUtils {
  // 1. 徽章門檻 (把原本的 _badgeMilestones 改成公開的 milestones)
  static final Map<String, List<int>> milestones = {
    'level_01': [1, 2, 3, 4, 5],
    'vocab_01': [10, 50, 100, 300, 500],
    'streak_01': [3, 7, 14, 30, 60],
    'marathon_01': [5, 15, 50, 100, 200],
    'camera_01': [10, 50, 200, 500, 1000],
  };

  // 2. 徽章基本資訊 (彈窗需要用到名稱與圖示)
  static final Map<String, Map<String, dynamic>> badgeInfo = {
    'level_01': {'title': '程度認證', 'icon': Icons.school},
    'vocab_01': {'title': '單字大富翁', 'icon': Icons.menu_book},
    'streak_01': {'title': '學習火種', 'icon': Icons.local_fire_department},
    'marathon_01': {'title': '學習馬拉松', 'icon': Icons.directions_run},
    'camera_01': {'title': '快門獵人', 'icon': Icons.camera_alt},
  };

  // 3. 計算等級 (修改參數：接收「進度數值」和「徽章 ID 字串」)
  static int calculateLevel(int progress, String badgeId) {
    // 透過 badgeId 自動去上面抓對應的門檻陣列
    final ms = milestones[badgeId] ?? [];
    int level = 0;
    for (int i = 0; i < ms.length; i++) {
      if (progress >= ms[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level;
  }

  // 4. 取得徽章顏色與樣式
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

  // 5. 日文等級轉換數字 (給程度認證徽章比對升級用)
  static int japaneseLevelToNumber(String? level) {
    switch (level) {
      case 'N5': return 1;
      case 'N4': return 2;
      case 'N3': return 3;
      case 'N2': return 4;
      case 'N1': return 5;
      default: return 0; // 尚未測驗或初學者
    }
  }
}
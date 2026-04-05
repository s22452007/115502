import 'package:flutter/material.dart';

class BadgeUtils {
  static const Map<String, List<int>> badgeMilestones = {
    'level_01': [1, 2, 3, 4, 5],
    'vocab_01': [10, 50, 100, 300, 500],
    'streak_01': [3, 7, 14, 30, 60],
    'marathon_01': [5, 15, 50, 100, 200],
    'camera_01': [10, 50, 200, 500, 1000],
  };

  static int calculateLevel(int progress, List<int> milestones) {
    int level = 0;
    for (int i = 0; i < milestones.length; i++) {
      if (progress >= milestones[i]) level = i + 1;
      else break;
    }
    return level;
  }

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
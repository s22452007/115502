import 'package:flutter/material.dart';
import '../../models/badge_model.dart';

class BadgeLibraryScreen extends StatefulWidget {
  const BadgeLibraryScreen({Key? key}) : super(key: key);

  @override
  State<BadgeLibraryScreen> createState() => _BadgeLibraryScreenState();
}

class _BadgeLibraryScreenState extends State<BadgeLibraryScreen> {
  // 🌟 核心 5 大徽章定義
  final List<BadgeModel> coreBadges = [
    BadgeModel(
      id: 'level_01', 
      title: '程度認證', 
      description: '透過測驗證明你的日語實力，邁向日語大師之路！', 
      icon: Icons.school,
      milestones: [1, 2, 3, 4, 5], // 對應 5 個等級
      levelLabels: ['N5 新手', 'N4 達人', 'N3 無礙', 'N2 菁英', 'N1 大師'],
    ),
    BadgeModel(
      id: 'vocab_01', 
      title: '單字大富翁', 
      description: '累計拍照解鎖並收藏新單字。', 
      icon: Icons.menu_book,
      milestones: [10, 50, 100, 300, 500],
    ),
    BadgeModel(
      id: 'streak_01', 
      title: '學習火種', 
      description: '每日持續登入學習，保持你的連勝火焰！', 
      icon: Icons.local_fire_department,
      milestones: [3, 7, 14, 30, 60],
    ),
    BadgeModel(
      id: 'marathon_01', 
      title: '學習馬拉松', 
      description: '累計使用 App 進行學習的總天數。', 
      icon: Icons.directions_run,
      milestones: [5, 15, 50, 100, 200],
    ),
    BadgeModel(
      id: 'camera_01', 
      title: '快門獵人', 
      description: '累計使用相機成功辨識物體的總次數。', 
      icon: Icons.camera_alt,
      milestones: [10, 50, 200, 500, 1000],
    ),
  ];

  // 🛡️ 模擬後端傳來的進度 (之後換成 Provider 的真實數據)
  final Map<String, int> _mockProgress = {
    'level_01': 3,       // N3 程度 (對應 level 3)
    'vocab_01': 120,     // 收集了 120 個單字 (對應 level 3, 銀牌)
    'streak_01': 5,      // 連續 5 天 (對應 level 1, 木牌)
    'marathon_01': 80,   // 總天數 80 天 (對應 level 3, 銀牌)
    'camera_01': 1150,   // 拍照 1150 次 (對應 level 5, 白金牌！)
  };

  // === 🎨 核心視覺邏輯：根據等級給予不同顏色與名稱 ===
  Map<String, dynamic> _getLevelTheme(int currentLevel) {
    switch (currentLevel) {
      case 5:
        return {'name': '白金級', 'color': Colors.purpleAccent, 'isGradient': true};
      case 4:
        return {'name': '金牌', 'color': Colors.amber[400]!, 'isGradient': false};
      case 3:
        return {'name': '銀牌', 'color': Colors.blueGrey[300]!, 'isGradient': false};
      case 2:
        return {'name': '銅牌', 'color': Colors.orange[700]!, 'isGradient': false};
      case 1:
        return {'name': '初階', 'color': Colors.brown[400]!, 'isGradient': false};
      default:
        return {'name': '未解鎖', 'color': Colors.grey[300]!, 'isGradient': false};
    }
  }

  // 計算目前落在哪個等級 (0=未解鎖, 1~5=對應等級)
  int _calculateLevel(int progress, List<int> milestones) {
    int level = 0;
    for (int i = 0; i < milestones.length; i++) {
      if (progress >= milestones[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: const Text('榮譽徽章', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4A7C59),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coreBadges.length,
        itemBuilder: (context, index) {
          final badge = coreBadges[index];
          final progress = _mockProgress[badge.id] ?? 0;
          final currentLevel = _calculateLevel(progress, badge.milestones);
          final theme = _getLevelTheme(currentLevel);
          
          // 處理進度條文字與上限
          final isMaxLevel = currentLevel == 5;
          final nextMilestone = isMaxLevel ? badge.milestones.last : badge.milestones[currentLevel];
          final progressRatio = isMaxLevel ? 1.0 : (progress / nextMilestone).clamp(0.0, 1.0);

          return GestureDetector(
            onTap: () => _showBadgeDetailDialog(badge, progress, currentLevel, theme),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  // 左側：動態外框徽章圖示
                  _buildBadgeIcon(badge.icon, theme, size: 60, iconSize: 30),
                  const SizedBox(width: 16),
                  
                  // 右側：文字與進度條
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(badge.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                            if (currentLevel > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme['isGradient'] ? Colors.transparent : (theme['color'] as Color).withOpacity(0.1),
                                  gradient: theme['isGradient'] 
                                      ? const LinearGradient(colors: [Colors.purple, Colors.blue]) 
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  badge.levelLabels != null ? badge.levelLabels![currentLevel - 1] : theme['name'],
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold, 
                                    color: theme['isGradient'] ? Colors.white : theme['color']
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 進度條
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              currentLevel > 0 && !theme['isGradient'] ? theme['color'] : const Color(0xFF4A7C59)
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isMaxLevel ? '已達成最高殿堂！ ($progress)' : '進度：$progress / $nextMilestone',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🌟 獨立的徽章圖示繪製工具 (支援漸層白金外框)
  Widget _buildBadgeIcon(IconData icon, Map<String, dynamic> theme, {required double size, required double iconSize}) {
    final bool isGradient = theme['isGradient'];
    final Color solidColor = isGradient ? Colors.white : theme['color'];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: solidColor.withOpacity(isGradient ? 1.0 : 0.1),
        // 外框魔法：如果是白金級，就套用漸層邊框；否則套用純色邊框
        gradient: isGradient ? const SweepGradient(colors: [Colors.purple, Colors.blue, Colors.pink, Colors.purple]) : null,
        border: !isGradient ? Border.all(color: solidColor, width: 3) : null,
      ),
      child: isGradient 
          // 白金級為了顯示外框漸層，內部再包一個白色圓形
          ? Padding(
              padding: const EdgeInsets.all(3.0),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Icon(icon, color: Colors.purple, size: iconSize),
              ),
            )
          : Icon(icon, color: solidColor, size: iconSize),
    );
  }

  // 🌟 彈出詳細視窗 (Pikmin Bloom 風格進度節點)
  void _showBadgeDetailDialog(BadgeModel badge, int progress, int currentLevel, Map<String, dynamic> theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 超大徽章
              _buildBadgeIcon(badge.icon, theme, size: 100, iconSize: 50),
              const SizedBox(height: 16),
              Text(badge.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(badge.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
              const SizedBox(height: 24),
              
              // 5 階里程碑節點展示
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('晉級軌跡：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
              
              Column(
                children: List.generate(5, (index) {
                  final isReached = currentLevel >= (index + 1);
                  final milestoneTheme = _getLevelTheme(index + 1); // 獲取該階層應有的顏色
                  final label = badge.levelLabels != null ? badge.levelLabels![index] : 'Lv.${index + 1}';
                  final target = badge.milestones[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        // 圓形小節點
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isReached ? (milestoneTheme['isGradient'] ? Colors.purple : milestoneTheme['color']) : Colors.grey[300],
                          ),
                          child: isReached ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        // 階級名稱與目標
                        Expanded(
                          child: Text(
                            '$label (目標: $target)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
                              color: isReached ? Colors.black87 : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A7C59),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('繼續努力', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
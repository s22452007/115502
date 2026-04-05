import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';

class LevelUpDialog {
  static Future<void> show(BuildContext context, String id, int level) async {
    final badgeInfo = {
      'level_01': {'title': '程度認證', 'icon': Icons.school},
      'vocab_01': {'title': '單字大富翁', 'icon': Icons.menu_book},
      'streak_01': {'title': '學習火種', 'icon': Icons.local_fire_department},
      'marathon_01': {'title': '學習馬拉松', 'icon': Icons.directions_run},
      'camera_01': {'title': '快門獵人', 'icon': Icons.camera_alt},
    };

    final info = badgeInfo[id]!;
    final theme = BadgeUtils.getLevelTheme(level);
    final bool isGradient = theme['isGradient'];
    final Color solidColor = isGradient ? Colors.white : theme['color'];

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            contentPadding: const EdgeInsets.all(32),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉 恭喜升級 🎉', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: solidColor.withOpacity(0.15),
                    gradient: isGradient ? const SweepGradient(colors: [Colors.purple, Colors.blue, Colors.pink, Colors.purple]) : null,
                    border: !isGradient ? Border.all(color: solidColor, width: 4) : null,
                    boxShadow: [BoxShadow(color: (isGradient ? Colors.purple : solidColor).withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: isGradient
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: Icon(info['icon'] as IconData, color: Colors.purple, size: 60),
                        )
                      : Icon(info['icon'] as IconData, color: solidColor, size: 70),
                ),
                const SizedBox(height: 28),
                Text(info['title'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('已解鎖【${theme['name']}】', style: TextStyle(fontSize: 18, color: isGradient ? Colors.purple : solidColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('你的努力有了回報！繼續保持下去！', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7C59),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('太棒了！', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
/// 徽章升級慶祝對話框
/// 負責在用戶徽章等級提升時顯示動畫慶祝對話框
/// 使用不同的顏色主題和動畫效果來慶祝用戶的學習成就
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';

class LevelUpDialog extends StatelessWidget {
  final String badgeId;
  final int level;

  const LevelUpDialog({Key? key, required this.badgeId, required this.level}) : super(key: key);

  static Future<void> show(BuildContext context, {required String badgeId, required int level}) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false, 
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.7), 
      transitionDuration: const Duration(milliseconds: 600), 
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: LevelUpDialog(badgeId: badgeId, level: level),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 從我們剛擴充的 BadgeUtils 拿資料
    final info = BadgeUtils.badgeInfo[badgeId]!;
    final theme = BadgeUtils.getLevelTheme(level);
    
    final bool isGradient = theme['isGradient'];
    final Color solidColor = isGradient ? Colors.white : theme['color'];
    final IconData iconData = info['icon'] as IconData;
    final String title = info['title'] as String;

    // ==========================================
    // 🌟 智慧文案判斷邏輯：給予專屬的對話框文字
    // ==========================================
    String topTitle = '🎉 恭喜升級 🎉';
    String descText = '你的努力有了回報！繼續保持下去！';
    String buttonText = '太棒了！';

    if (badgeId == 'level_01') {
      if (level == 1) {
        // 🎁 專屬迎新禮包 (N5 新手)
        topTitle = '🎉 歡迎加入 🎉';
        descText = '這是專屬於你的新手徽章，準備好開始你的日語探索之旅了嗎？';
        buttonText = '開始探索！';
      } else {
        // 🎓 老手測驗出來的結果 (N4~N1)
        topTitle = '🎉 程度認證 🎉';
        descText = '太厲害了！AI 已經為您設定好專屬的學習起點囉！';
        buttonText = '開始學習！';
      }
    } else if (badgeId == 'streak_01') {
      descText = '燃燒吧學習之魂！請繼續保持這份毅力！';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.all(32),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 這裡換成動態的 topTitle
          Text(topTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 28),
          
          // 發光大徽章
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: solidColor.withOpacity(0.15),
              gradient: isGradient ? const SweepGradient(colors: [Colors.purple, Colors.blue, Colors.pink, Colors.purple]) : null,
              border: !isGradient ? Border.all(color: solidColor, width: 4) : null,
              boxShadow: [
                BoxShadow(color: (isGradient ? Colors.purple : solidColor).withOpacity(0.5), blurRadius: 30, spreadRadius: 5)
              ],
            ),
            child: isGradient
                ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Icon(iconData, color: Colors.purple, size: 60),
                  )
                : Icon(iconData, color: solidColor, size: 70),
          ),
          
          const SizedBox(height: 28),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('已解鎖【${theme['name']}】', style: TextStyle(fontSize: 18, color: isGradient ? Colors.purple : solidColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // 這裡換成動態的 descText
          Text(descText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
              // 這裡換成動態的 buttonText
              child: Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
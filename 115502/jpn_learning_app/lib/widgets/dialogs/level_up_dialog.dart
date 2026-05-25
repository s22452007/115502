/// 徽章升級慶祝對話框 (扁平化極簡綠色版)
/// 負責在用戶徽章等級提升時顯示動畫慶祝對話框
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';

class LevelUpDialog extends StatelessWidget {
  final String badgeId;
  final int level;

  const LevelUpDialog({Key? key, required this.badgeId, required this.level}) : super(key: key);

  static Future<void> show(BuildContext context, {required String badgeId, required int level}) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true, // 允許點擊外部關閉
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6), // 稍微調暗一點，讓發光更明顯
      transitionDuration: const Duration(milliseconds: 600), // 彈出時間稍微拉長一點點
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        // 保留果凍彈出動畫
        final curvedValue = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: curvedValue,
          child: Opacity(
            opacity: anim1.value,
            child: LevelUpDialog(badgeId: badgeId, level: level),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 取得徽章資料
    final info = BadgeUtils.badgeInfo[badgeId]!;
    final theme = BadgeUtils.getLevelTheme(level);
    
    final IconData iconData = info['icon'] as IconData;
    final String badgeTitle = info['title'] as String;

    // ==========================================
    // 扁平化配色系統 (以綠色為主)
    // ==========================================
    const Color primaryGreen = Color(0xFF4A7C59); // 主題綠 (扁平)
    const Color vibrantGlowGreen = Color(0xFF00E676); // 用來發光的亮綠色
    const Color darkTextColor = Color(0xFF2C3E50); // 深色文字
    const Color grayTextColor = Color(0xFF8E9AAB); // 次要敘述文字

    // ==========================================
    // 智慧文案與單色 Icon 判斷邏輯
    // ==========================================
    String topTitle = '恭喜升級';
    String descText = '你的努力有了回報！繼續保持下去！';
    String buttonText = '太棒了';
    IconData topIcon = Icons.military_tech_rounded; 

    if (badgeId == 'level_01') {
      if (level == 1) {
        topTitle = '歡迎加入';
        descText = '這是專屬於你的新手徽章，準備好開始你的日語探索之旅了嗎？';
        buttonText = '開始探索';
        topIcon = Icons.flag_rounded;
      } else {
        topTitle = '程度認證';
        descText = '太厲害了！AI 已經為您設定好專屬的學習起點囉！';
        buttonText = '開始學習';
        topIcon = Icons.school_rounded;
      }
    } else if (badgeId == 'streak_01') {
      topTitle = '連續登入';
      descText = '燃燒吧學習之魂！請繼續保持這份毅力！';
      topIcon = Icons.local_fire_department_rounded;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28), // 圓角稍微加大，更有勳章盒感
          // 🌟 卡片外圍加上超淡淡的發光，讓卡片更輕盈
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.05),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---------------- 🌟 重點：發光勳章區塊 (實體化、邊框、發光) ----------------
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, // 改為純白底色凸顯 Icon
                shape: BoxShape.circle,
                // 1. 🌟 加入實體深綠色圓形邊框 (勳章感)
                border: Border.all(color: primaryGreen, width: 4),
                // 2. 🌟 霓虹發光特效 (層疊 BoxShadow)
                boxShadow: [
                  // 內層：強烈綠色光暈
                  BoxShadow(
                    color: vibrantGlowGreen.withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  // 外層：擴散的淡淡綠色光圈
                  BoxShadow(
                    color: vibrantGlowGreen.withOpacity(0.2),
                    blurRadius: 50,
                    spreadRadius: 15,
                  ),
                ],
              ),
              child: Icon(
                iconData, 
                color: primaryGreen, // 保持單色 Icon
                size: 70, // 稍微加大 Icon 尺寸
              ),
            ),
            const SizedBox(height: 32),
            
            // ---------------- 小標題 (帶單色 Icon) ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(topIcon, color: primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  topTitle,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // ---------------- 徽章大標題 ----------------
            Text(
              badgeTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: darkTextColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            // ---------------- 已解鎖稱號 (若有) ----------------
            if (theme['name'] != null && theme['name'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '已解鎖【${theme['name']}】', 
                  style: const TextStyle(
                    fontSize: 16, 
                    color: primaryGreen, 
                    fontWeight: FontWeight.w800,
                  )
                ),
              ),
            
            // ---------------- 內文描述 (扁平化極簡) ----------------
            Text(
              descText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: grayTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 36),
            
            // ---------------- 扁平化確認按鈕 (綠色為主) ----------------
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen, 
                  elevation: 0, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
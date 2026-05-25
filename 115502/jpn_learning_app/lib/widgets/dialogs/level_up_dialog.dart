/// 徽章升級慶祝對話框 (扁平綠色 + 黃金發光裝飾版)
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
      barrierColor: Colors.black.withOpacity(0.65), // 加深一點點背景，讓金光更耀眼
      transitionDuration: const Duration(milliseconds: 600), 
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        // 果凍彈出動畫
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
    // 配色系統：主體扁平綠 + 裝飾黃金發光
    // ==========================================
    const Color primaryGreen = Color(0xFF4A7C59); // 主題綠 (扁平)
    const Color goldGlow = Color(0xFFFFD700);     // 亮金色 (發光與裝飾)
    const Color darkGold = Color(0xFFFFB300);     // 深金色 (增加星星層次)
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
          borderRadius: BorderRadius.circular(28), 
          // 淡淡卡片背景光，讓整體更輕盈
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
            // ---------------- 🌟 升級版：金色發光與外圍裝飾的勳章 ----------------
            Stack(
              clipBehavior: Clip.none, // 允許裝飾的星星稍微超出邊界
              alignment: Alignment.center,
              children: [
                // 1. 金色霓虹發光底層 (Golden Aura)
                Container(
                  width: 100, // 控制發光範圍
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // 內層：強烈金色光暈
                      BoxShadow(color: goldGlow.withOpacity(0.65), blurRadius: 30, spreadRadius: 6),
                      // 外層：擴散的淡淡金色光圈
                      BoxShadow(color: goldGlow.withOpacity(0.25), blurRadius: 60, spreadRadius: 20),
                    ],
                  ),
                ),
                
                // 2. 外圍金色裝飾 (漂浮的星星與閃光)
                Positioned(
                  top: -10, 
                  left: -15, 
                  child: Icon(Icons.auto_awesome_rounded, color: goldGlow, size: 32),
                ),
                Positioned(
                  bottom: -5, 
                  right: -20, 
                  child: Icon(Icons.star_rounded, color: darkGold, size: 28),
                ),
                Positioned(
                  top: 15, 
                  right: -10, 
                  child: Icon(Icons.circle, color: goldGlow.withOpacity(0.8), size: 8),
                ),
                Positioned(
                  bottom: 20, 
                  left: -25, 
                  child: Icon(Icons.star_border_rounded, color: darkGold, size: 22),
                ),

                // 3. 實體深綠色外框 + 白底單色圖示 (核心徽章)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryGreen, width: 4.5), // 厚實的金屬感邊框
                  ),
                  child: Icon(
                    iconData, 
                    color: primaryGreen, // 保持扁平化單色 Icon
                    size: 68,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            
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
            
            // ---------------- 內文描述 ----------------
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
            
            // ---------------- 扁平化確認按鈕 ----------------
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
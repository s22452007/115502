import 'package:flutter/material.dart';

// 引入首頁與我們的工具箱、彈窗
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/helpers.dart';
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';

/// 程度測驗結果頁。
/// 版面跟測驗頁（QuickTestScreen）同一套：米白底、白色圓角卡片、主綠色。
/// 不顯示 N5～N1 代碼或 S/A/B/C/D 評分，只用稱號，並用階梯讓使用者看懂自己在哪一級、接下來還有哪些。
class TestResultScreen extends StatelessWidget {
  final String levelCode; // 後端傳來的乾淨代碼 (N5, N4, N3, N2, N1)
  final int? correctCount; // 答對題數（舊的呼叫端沒傳就不顯示）
  final int? totalCount;

  const TestResultScreen({
    Key? key,
    required this.levelCode,
    this.correctCount,
    this.totalCount,
  }) : super(key: key);

  static const _ladder = ['N5', 'N4', 'N3', 'N2', 'N1'];
  static const _emoji = {'N5': '🌱', 'N4': '🚶', 'N3': '🗣️', 'N2': '💼', 'N1': '🎓'};

  // 稱號統一取自 AppHelpers.getLevelTitle，跟個人檔案顯示的一樣
  String get displayTitle => AppHelpers.getLevelTitle(levelCode);

  Future<void> _start(BuildContext context) async {
    // 噴發「程度認證」徽章的慶祝彈窗，關掉後進首頁
    await LevelUpDialog.show(context, badgeId: 'level_01', level: BadgeUtils.japaneseLevelToNumber(levelCode));
    if (context.mounted) {
      // 清空導覽紀錄，避免按返回鍵又回到測驗結果
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _ladder.indexOf(levelCode).clamp(0, _ladder.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Column(
                      children: [
                        const Text('測驗完成！',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.title)),
                        const SizedBox(height: 6),
                        const Text('我們依照你的作答，幫你找到合適的起點',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                        const SizedBox(height: 24),
                        _buildResultCard(),
                        const SizedBox(height: 16),
                        _buildLadderCard(current),
                        const SizedBox(height: 16),
                        _buildNote(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _start(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('開始探索', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 主結果：稱號徽章 + 答對題數
  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderGreen, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(_emoji[levelCode] ?? '🌱', style: const TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 16),
          const Text('你的起點稱號', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text(displayTitle,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
          if (correctCount != null && totalCount != null && totalCount! > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('答對 $correctCount / $totalCount 題',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }

  /// 稱號階梯：讓使用者知道自己在第幾級、後面還有哪些
  Widget _buildLadderCard(int current) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('稱號等級', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.title)),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_ladder.length, (i) {
              final reached = i <= current;
              final isCurrent = i == current;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 左半段連接線（第一格不畫）
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i == 0 ? Colors.transparent : (reached ? AppColors.primary : AppColors.borderLight),
                          ),
                        ),
                        Container(
                          width: isCurrent ? 34 : 26,
                          height: isCurrent ? 34 : 26,
                          decoration: BoxDecoration(
                            color: reached ? AppColors.primary : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: reached ? AppColors.primary : AppColors.borderLight, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: reached
                              ? Icon(isCurrent ? Icons.star_rounded : Icons.check_rounded,
                                  size: isCurrent ? 20 : 15, color: Colors.white)
                              : null,
                        ),
                        // 右半段連接線（最後一格不畫）
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i == _ladder.length - 1
                                ? Colors.transparent
                                : (i < current ? AppColors.primary : AppColors.borderLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppHelpers.getLevelTitle(_ladder[i]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w500,
                        color: isCurrent ? AppColors.primary : (reached ? AppColors.textDark : AppColors.textSubtle),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 說明：之後可以挑戰升級
  Widget _buildNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 20, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '之後可以在「個人檔案」挑戰升級測驗，解鎖更高的稱號。',
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

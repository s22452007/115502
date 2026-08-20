import 'package:flutter/material.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';

/// 主題收集冊的引導畫面。
///
/// 解決兩個使用者困惑：
/// 1. 不知道「主題收集冊」在幹嘛 → 用三個步驟講清楚照片怎麼變成一本冊子。
/// 2. 看到鎖頭以為解鎖要付費 → 明確寫出拍照解鎖不花點數，點數只用在收藏與擴充。
///
/// 首次進入收集冊時自動出現，之後可從右上角的「?」再打開。
class ThemeCollectionIntroScreen extends StatelessWidget {
  /// 首次自動彈出時為 true；從「?」或空狀態手動打開時為 false（只影響按鈕文案）。
  final bool isFirstTime;

  const ThemeCollectionIntroScreen({Key? key, this.isFirstTime = true})
      : super(key: key);

  static const List<List<String>> _steps = [
    ['拍下眼前的東西', '便當、車站看板、教室桌上的文具都可以，不用特別找教材。'],
    ['單字自動歸進主題', '系統辨識出照片裡的日文單字，依照生活情境放進「飲食」「交通」「校園」等收集冊。'],
    ['把一本冊子集滿', '同一個主題的單字牆會慢慢點亮，集滿就代表這個情境的字你都碰過了。'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textGrey),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  const Text(
                    '把眼前的東西\n變成一本單字圖鑑',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '主題收集冊會把你拍過的照片，依生活情境整理成一本本冊子。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  for (int i = 0; i < _steps.length; i++)
                    _StepRow(
                      index: i + 1,
                      title: _steps[i][0],
                      body: _steps[i][1],
                      isLast: i == _steps.length - 1,
                    ),

                  const SizedBox(height: 28),
                  const _FreeNotice(),
                ],
              ),
            ),

            // 底部動作區
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      onPressed: () {
                        // 直接接到相機，引導完就能馬上開出第一本冊子
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraScreen()),
                        );
                      },
                      child: const Text(
                        '開始拍第一張',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      isFirstTime ? '先看看收集冊' : '知道了',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 編號步驟：數字 + 細線串起來，不用圓框圖示
class _StepRow extends StatelessWidget {
  final int index;
  final String title;
  final String body;
  final bool isLast;

  const _StepRow({
    required this.index,
    required this.title,
    required this.body,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側：序號與連接線
          Column(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$index',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: AppColors.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 免費說明：直接回答「解鎖是不是要花點數」
class _FreeNotice extends StatelessWidget {
  const _FreeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '解鎖單字不用花點數',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '拍照辨識出來的單字會直接進到你的收集冊，完全免費，每天只有拍照次數的限制。',
            style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          const Text(
            '點數只有在「把單字收藏到資料夾」或「擴充資料夾容量」時才會用到。',
            style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

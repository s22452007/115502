import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/common/furigana_text.dart';

/// AI 造句批改結果的共用區塊（拍照後的「練習造句」與「造句練習」共用）：
///   你的句子 → 修改建議（原本 → 改成 + 一句原因）→ 參考句子（讀音標在漢字上方）＋ 翻譯
/// 不再把 AI 的說明塞成一大段文字。
class SentenceFeedbackSections extends StatelessWidget {
  final String? userSentence;
  final List corrections; // [{original, corrected, reason}]
  final String correctedSentence; // 可含 [漢字|かな] 讀音標記
  final String translation;
  final bool isCorrect;

  /// 舊格式（沒有 corrections）時顯示的整段點評
  final String fallbackFeedback;

  const SentenceFeedbackSections({
    super.key,
    this.userSentence,
    required this.corrections,
    required this.correctedSentence,
    this.translation = '',
    this.isCorrect = false,
    this.fallbackFeedback = '',
  });

  @override
  Widget build(BuildContext context) {
    final items = corrections.whereType<Map>().toList();
    final sentence = userSentence?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 句子正確時，下面的「含讀音」版本就是同一句，不重複顯示
        if (sentence.isNotEmpty && !(isCorrect && correctedSentence.isNotEmpty)) ...[
          _label('你的句子'),
          Text(sentence, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textGrey)),
        ],
        if (items.isNotEmpty) ...[
          _label('修改建議'),
          ...items.map(_correctionItem),
        ] else if (!isCorrect && fallbackFeedback.trim().isNotEmpty) ...[
          _label('老師的點評'),
          Text(fallbackFeedback.trim(), style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textDark)),
        ],
        if (correctedSentence.isNotEmpty) ...[
          _label(isCorrect ? '你的句子（含讀音）' : '參考句子'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FuriganaText(text: correctedSentence, fontSize: 19, textColor: AppColors.textDark),
                if (translation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(translation, style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  static Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSubtle)),
    );
  }

  /// 一筆修改建議：紅色刪除線的原寫法 → 綠色的新寫法，下面一行原因
  static Widget _correctionItem(Map c) {
    final original = (c['original'] ?? '').toString();
    final fixed = (c['corrected'] ?? '').toString();
    final reason = (c['reason'] ?? '').toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(original,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.error,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.error,
                  )),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSubtle),
              Text(fixed, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark)),
          ],
        ],
      ),
    );
  }
}

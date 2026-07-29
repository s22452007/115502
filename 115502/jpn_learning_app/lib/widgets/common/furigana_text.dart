import 'package:flutter/material.dart';

class _FuriganaToken {
  final String kanji;
  final String? furigana;

  _FuriganaToken(this.kanji, [this.furigana]);
}

/// 通用日文假名標音 (Furigana / Ruby) 排版元件
/// 支援語法：
/// 1. `[漢字|假名]` (如：`[私|わたし]は[毎日|まいにち]`)
/// 2. `漢字[假名]` (如：`私[わたし]は毎日[まいにち]`)
/// 
/// 標音將自動以 **淺灰色 (`Colors.grey.shade600`)** 懸浮顯示於漢字上方，
/// 且所有文字均保持底部對齊與舒適的行距。
class FuriganaText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color textColor;
  final FontWeight fontWeight;

  const FuriganaText({
    Key? key,
    required this.text,
    this.fontSize = 15.0,
    this.textColor = Colors.black,
    this.fontWeight = FontWeight.normal,
  }) : super(key: key);

  /// 語音發音 (TTS) 清理函數：
  /// 將帶有 `[漢字|假名]` 或 `漢字[假名]` 格式的字串還原為純純的日文句子，
  /// 避免 TTS 朗讀時念出方括號或分隔符號。
  static String cleanFuriganaForTts(String rawText) {
    if (rawText.isEmpty) return '';
    // 1. 移除 [漢字|假名] 格式，留下漢字（第1群組）
    String cleaned = rawText.replaceAllMapped(
      RegExp(r'\[([^|\]]+)\|([^\]]+)\]'),
      (match) => match.group(1) ?? '',
    );
    // 2. 移除 漢字[假名] 格式，留下漢字（第1群組）
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\u4e00-\u9faf\u3400-\u4dbf々]+)\[([a-zA-Z\u3040-\u309f\u30a0-\u30ff]+)\]'),
      (match) => match.group(1) ?? '',
    );
    return cleaned;
  }

  static List<_FuriganaToken> _parseTokens(String rawText) {
    final List<_FuriganaToken> tokens = [];
    if (rawText.isEmpty) return tokens;

    // 匹配兩種常見格式： [漢字|假名] 或 漢字[假名]
    final regex = RegExp(
      r'\[([^|\]]+)\|([^\]]+)\]|([\u4e00-\u9faf\u3400-\u4dbf々]+)\[([a-zA-Z\u3040-\u309f\u30a0-\u30ff]+)\]',
    );

    int currentIndex = 0;
    for (final match in regex.allMatches(rawText)) {
      if (match.start > currentIndex) {
        final normalText = rawText.substring(currentIndex, match.start);
        _addNormalTextTokens(tokens, normalText);
      }

      if (match.group(1) != null) {
        // 格式 1: [漢字|假名]
        _addAnnotatedToken(tokens, match.group(1)!, match.group(2)!);
      } else if (match.group(3) != null) {
        // 格式 2: 漢字[假名]
        _addAnnotatedToken(tokens, match.group(3)!, match.group(4)!);
      }

      currentIndex = match.end;
    }

    if (currentIndex < rawText.length) {
      final trailingText = rawText.substring(currentIndex);
      _addNormalTextTokens(tokens, trailingText);
    }

    return tokens;
  }

  /// 加入一個標音詞：若標音與本體完全相同（例如 AI 誤把假名標成 [こんにちは|こんにちは]），
  /// 視為冗餘標音，改以一般文字呈現，避免同樣的字上下重複顯示。
  static void _addAnnotatedToken(
    List<_FuriganaToken> tokens,
    String base,
    String furigana,
  ) {
    if (base == furigana) {
      _addNormalTextTokens(tokens, base);
    } else {
      tokens.add(_FuriganaToken(base, furigana));
    }
  }

  /// 將沒有標音的一般文字進行細分：
  /// 英數字維持完整單詞不被切斷，日文字元與標點符號則逐字獨立排版，確保 Wrap 排版自然順暢。
  static void _addNormalTextTokens(List<_FuriganaToken> tokens, String text) {
    final regex = RegExp(r'[a-zA-Z0-9]+|.');
    for (final match in regex.allMatches(text)) {
      final tokenStr = match.group(0);
      if (tokenStr != null && tokenStr.isNotEmpty) {
        tokens.add(_FuriganaToken(tokenStr));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _parseTokens(text);

    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 0,
      runSpacing: 6,
      children: tokens.map((t) {
        if (t.furigana != null && t.furigana!.isNotEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.furigana!,
                style: TextStyle(
                  fontSize: fontSize * 0.55,
                  color: Colors.grey.shade600, // 淺灰色
                  height: 1.1,
                ),
              ),
              Text(
                t.kanji,
                style: TextStyle(
                  fontSize: fontSize,
                  color: textColor,
                  fontWeight: fontWeight,
                  height: 1.2,
                ),
              ),
            ],
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 透明佔位符，保證全句所有文字的高度與底部基準線完全對齊
              Text(
                ' ',
                style: TextStyle(
                  fontSize: fontSize * 0.55,
                  color: Colors.transparent,
                  height: 1.1,
                ),
              ),
              Text(
                t.kanji,
                style: TextStyle(
                  fontSize: fontSize,
                  color: textColor,
                  fontWeight: fontWeight,
                  height: 1.2,
                ),
              ),
            ],
          );
        }
      }).toList(),
    );
  }
}

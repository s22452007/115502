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
    // 3. 去掉沒有讀音的強調框 [文字]
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([^|\[\]]+)\]'),
      (match) => match.group(1) ?? '',
    );
    return cleaned;
  }

  static List<_FuriganaToken> _parseTokens(String rawText) {
    final List<_FuriganaToken> tokens = [];
    if (rawText.isEmpty) return tokens;

    // 匹配兩種常見格式： [漢字|假名] 或 漢字[假名]
    // 第 3 種是 AI 自己加的強調框（例如把指定單字寫成 [リード]），沒有讀音，去掉括號當一般文字
    final regex = RegExp(
      r'\[([^|\]]+)\|([^\]]+)\]|([\u4e00-\u9faf\u3400-\u4dbf々]+)\[([a-zA-Z\u3040-\u309f\u30a0-\u30ff]+)\]|\[([^|\[\]]+)\]',
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
      } else if (match.group(5) != null) {
        // 沒有讀音的 [文字]：只是強調框，照一般文字顯示
        _addNormalTextTokens(tokens, match.group(5)!);
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
    final scaler = MediaQuery.textScalerOf(context);
    final baseStyle = TextStyle(fontSize: fontSize, color: textColor, fontWeight: fontWeight, height: 1.2);
    final rubyStyle = TextStyle(fontSize: fontSize * 0.55, color: Colors.grey.shade600, height: 1.1);
    final rubyHeight = scaler.scale(fontSize * 0.55) * 1.1;

    bool plainAt(int i) => i >= 0 && i < tokens.length && (tokens[i].furigana?.isEmpty ?? true);

    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 0,
      runSpacing: 6,
      children: List.generate(tokens.length, (i) {
        final t = tokens[i];
        if (t.furigana != null && t.furigana!.isNotEmpty) {
          return _rubyToken(t, baseStyle, rubyStyle, rubyHeight,
              leftFree: plainAt(i - 1), rightFree: plainAt(i + 1));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 讀音那一行的空白佔位，讓全句的字底部對齊
            SizedBox(height: rubyHeight),
            Text(t.kanji, style: baseStyle),
          ],
        );
      }),
    );
  }

  /// 有讀音的字。讀音比漢字寬時（例如「私」上面的「わたし」），原本整格會被撐成讀音的寬度，
  /// 漢字後面就空出一塊（「私　の」）。現在格子寬度只看漢字，讀音可以延伸到旁邊
  /// 「沒有讀音」的字上方，漢字之間就不會有空隙；兩邊都是有讀音的字時才照舊撐開，避免讀音重疊。
  /// 不用 TextPainter 量字寬（量的字型跟實際顯示的不一定一樣，網頁版中文字型還是延後載入的），
  /// 改由漢字本身決定格子大小，讀音用 OverflowBox 允許超出。
  Widget _rubyToken(
    _FuriganaToken t,
    TextStyle baseStyle,
    TextStyle rubyStyle,
    double rubyHeight, {
    required bool leftFree,
    required bool rightFree,
  }) {
    final ruby = Text(t.furigana!, style: rubyStyle, softWrap: false, maxLines: 1);
    final base = Text(t.kanji, style: baseStyle, softWrap: false, maxLines: 1);

    // 兩邊都有讀音（或在句首、句尾又只有一邊）：照原本的方式，寬度取讀音和漢字較寬的那個
    if (!leftFree && !rightFree) {
      return Column(mainAxisSize: MainAxisSize.min, children: [ruby, base]);
    }

    // 假名、漢字幾乎等寬，用字數估讀音會不會比漢字寬（讀音字級是 0.55 倍）
    final rubyWider = t.furigana!.length * 0.55 > t.kanji.length;
    final Alignment align;
    if (!rubyWider || (leftFree && rightFree)) {
      align = Alignment.center; // 置中，必要時左右各超出一點
    } else if (rightFree) {
      align = Alignment.centerLeft; // 左邊也有讀音：只往右延伸
    } else {
      align = Alignment.centerRight; // 右邊也有讀音：只往左延伸
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: EdgeInsets.only(top: rubyHeight), child: base),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: rubyHeight,
          child: OverflowBox(maxWidth: double.infinity, alignment: align, child: ruby),
        ),
      ],
    );
  }
}

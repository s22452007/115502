import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/common/furigana_text.dart';

/// 語法小教室：練習造句批改後，從結果卡片開啟的底部彈窗。
/// 「你的說法」標出原句要改的片段，「道地說法」顯示修正句；
/// 下面逐筆列出修改（以語法／詞彙標籤區分），最後是老師講解。
class GrammarTipScreen extends StatefulWidget {
  final String userSentence;
  final String correctedSentence; // 可含 [漢字|かな] 讀音標記
  final String translation;
  final List<Map> corrections; // [{original, corrected, reason, type}]
  final String grammarNote;

  const GrammarTipScreen({
    super.key,
    required this.userSentence,
    required this.correctedSentence,
    required this.corrections,
    this.translation = '',
    this.grammarNote = '',
  });

  static Future<void> show(
    BuildContext context, {
    required String userSentence,
    required String correctedSentence,
    required List<Map> corrections,
    String translation = '',
    String grammarNote = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GrammarTipScreen(
        userSentence: userSentence,
        correctedSentence: correctedSentence,
        corrections: corrections,
        translation: translation,
        grammarNote: grammarNote,
      ),
    );
  }

  @override
  State<GrammarTipScreen> createState() => _GrammarTipScreenState();
}

class _GrammarTipScreenState extends State<GrammarTipScreen> {
  bool _showNative = false; // false＝你的說法，true＝道地說法

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('語法小教室', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Row(children: [
                  _TabBtn(label: '你的說法', selected: !_showNative, onTap: () => setState(() => _showNative = false)),
                  const SizedBox(width: 8),
                  _TabBtn(label: '道地說法', selected: _showNative, onTap: () => setState(() => _showNative = true)),
                ]),
                const SizedBox(height: 12),
                _buildSentenceBox(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.corrections.isNotEmpty) ...[
                          _label('重點'),
                          ...widget.corrections.map(_correctionItem),
                        ],
                        if (widget.grammarNote.isNotEmpty) ...[
                          _label('老師講解'),
                          _buildNote(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('了解！', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceBox() {
    if (_showNative) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FuriganaText(text: widget.correctedSentence, fontSize: 19, textColor: AppColors.textDark),
            if (widget.translation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.translation, style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.4)),
            ],
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text.rich(
        TextSpan(children: _highlightOriginals()),
        style: const TextStyle(fontSize: 18, height: 1.6, color: AppColors.textDark),
      ),
    );
  }

  /// 把原句中要改的片段標紅底線，其他照原樣顯示
  List<TextSpan> _highlightOriginals() {
    final sentence = widget.userSentence;
    final ranges = <List<int>>[];
    for (final c in widget.corrections) {
      final original = (c['original'] ?? '').toString();
      if (original.isEmpty) continue;
      final start = sentence.indexOf(original);
      if (start < 0) continue;
      final end = start + original.length;
      if (ranges.any((r) => start < r[1] && end > r[0])) continue; // 重疊的就不重複標
      ranges.add([start, end]);
    }
    ranges.sort((a, b) => a[0].compareTo(b[0]));

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r[0] > cursor) spans.add(TextSpan(text: sentence.substring(cursor, r[0])));
      spans.add(TextSpan(
        text: sentence.substring(r[0], r[1]),
        style: const TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.error,
        ),
      ));
      cursor = r[1];
    }
    if (cursor < sentence.length) spans.add(TextSpan(text: sentence.substring(cursor)));
    return spans;
  }

  Widget _correctionItem(Map c) {
    final original = (c['original'] ?? '').toString();
    final fixed = (c['corrected'] ?? '').toString();
    final reason = (c['reason'] ?? '').toString();
    final isVocab = (c['type'] ?? '').toString() == '詞彙';
    final tagColor = isVocab ? AppColors.gold : AppColors.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isVocab ? '詞彙' : '語法',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tagColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(original,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.error,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.error,
                        )),
                    const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.textSubtle),
                    Text(fixed, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
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

  Widget _buildNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryLighter,
          child: Text('👩‍🏫', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(widget.grammarNote,
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textDark)),
        ),
      ],
    );
  }

  static Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSubtle)),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontSize: 13)),
      ),
    );
  }
}

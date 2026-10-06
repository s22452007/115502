import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/widgets/common/sentence_feedback.dart';
import 'package:jpn_learning_app/screens/scenario/grammar_tip_screen.dart';

class MakeSentenceScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> vocabs;
  final String? contextDescription;

  const MakeSentenceScreen({
    Key? key,
    required this.imagePath,
    required this.vocabs,
    this.contextDescription,
  }) : super(key: key);

  @override
  State<MakeSentenceScreen> createState() => _MakeSentenceScreenState();
}

class _MakeSentenceScreenState extends State<MakeSentenceScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _feedbackResult;
  String? _errorMessage;
  String? _submittedSentence;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitSentence() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _feedbackResult = null;
      _submittedSentence = text;
    });

    try {
      final response = await ApiClient.client.post(
        Uri.parse('${ApiClient.baseUrl}/scenario/evaluate_sentence'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sentence': text,
          'vocabs': widget.vocabs,
          'context_description': widget.contextDescription,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _feedbackResult = data;
        });
      } else {
        setState(() {
          _errorMessage = data['error'] ?? '評估發生錯誤，請稍後再試。';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '網路錯誤，請檢查您的連線。';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// AI 批改結果：分成「總評 → 你的句子 → 修改建議 → 參考句子」四區，
  /// 不再把整段說明塞成一大段文字；後三區用共用的 SentenceFeedbackSections。
  Widget _buildFeedbackCard() {
    if (_feedbackResult == null) return const SizedBox.shrink();

    final isValid = _feedbackResult!['is_valid'] == true;
    final feedback = (_feedbackResult!['feedback'] ?? '').toString();
    final corrected = (_feedbackResult!['corrected_sentence'] ?? '').toString();
    final translation = (_feedbackResult!['translation'] ?? '').toString();
    final corrections = (_feedbackResult!['corrections'] as List? ?? [])
        .whereType<Map>()
        .toList();

    final accent = isValid ? AppColors.primary : const Color(0xFFE08A1E);
    final title = isValid
        ? '句子完全正確！'
        : (corrections.isEmpty ? 'AI 老師的回饋' : '有 ${corrections.length} 個地方可以更好');

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35)),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 總評
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(isValid ? Icons.check_rounded : Icons.lightbulb_outline_rounded, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: accent)),
                    if (feedback.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(feedback, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textDark)),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 2～4. 你的句子 → 修改建議 → 參考句子（與造句練習共用）
          SentenceFeedbackSections(
            userSentence: _submittedSentence,
            corrections: corrections,
            correctedSentence: corrected,
            translation: translation,
            isCorrect: isValid,
          ),

          if (corrections.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => GrammarTipScreen.show(
                  context,
                  userSentence: _submittedSentence ?? '',
                  correctedSentence: corrected,
                  corrections: corrections,
                  translation: translation,
                  grammarNote: (_feedbackResult!['grammar_note'] ?? '').toString(),
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: const Text('語法小教室', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPageTemplate(
      title: '練習造句',
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: OutlinedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textGrey,
              side: const BorderSide(color: AppColors.borderLight),
              fixedSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('跳過 / 回主頁', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '利用剛剛辨識出的單字，試著造一個日文句子吧！',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.vocabs.map((v) {
                  final String word = v['word'] ?? '';
                  final String kana = v['kana'] ?? '';
                  final bool hasKanji = word.isNotEmpty && word != kana;

                  return Chip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasKanji)
                          Text(
                            kana,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.0,
                              color: AppColors.primary.withOpacity(0.8),
                            ),
                          ),
                        Text(
                          word.isNotEmpty ? word : kana,
                          style: const TextStyle(
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                    side: const BorderSide(color: AppColors.primaryLight),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '請輸入您的日文句子...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSentence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '送出評估',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              _buildFeedbackCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

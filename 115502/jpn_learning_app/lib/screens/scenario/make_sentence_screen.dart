import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

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
    });

    try {
      final response = await http.post(
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

  Widget _buildFeedbackCard() {
    if (_feedbackResult == null) return const SizedBox.shrink();

    final isValid = _feedbackResult!['is_valid'] == true;
    final feedback = _feedbackResult!['feedback'] ?? '';
    final corrected = _feedbackResult!['corrected_sentence'] ?? '';
    final translation = _feedbackResult!['translation'] ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValid ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.thumb_up : Icons.lightbulb,
                color: isValid ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isValid ? '太棒了！' : 'AI 老師的回饋',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (corrected.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '日文例句：',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              corrected,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
          if (translation.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '中文翻譯：',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              translation,
              style: const TextStyle(fontSize: 16),
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
                  return Chip(
                    label: Text(v['word'] ?? v['kana'] ?? ''),
                    backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                    side: const BorderSide(color: AppColors.primaryLight),
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

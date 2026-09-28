import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

/// 文章閱讀作業（附測驗）的作答畫面。
///
/// 上半部顯示老師指定的文章，下半部是老師出的題目：
///   single_choice：四選一，answer 為 A～D
///   true_false   ：是非題，answer 為 O / X
/// 送出後由後端 /api/assignment/submit_quiz 自動閱卷並繳交。
class ArticleQuizScreen extends StatefulWidget {
  /// GET /api/assignment/<id> 回傳的 assignment 物件（含 config 與 article）
  final Map<String, dynamic> assignment;

  const ArticleQuizScreen({Key? key, required this.assignment}) : super(key: key);

  @override
  State<ArticleQuizScreen> createState() => _ArticleQuizScreenState();
}

class _ArticleQuizScreenState extends State<ArticleQuizScreen> {
  late final List<Map<String, dynamic>> _questions;
  late final Map<String, dynamic> _article;
  final Map<int, String> _answers = {};
  bool _showTranslation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final config = Map<String, dynamic>.from(widget.assignment['config'] ?? {});
    _questions = List<Map<String, dynamic>>.from(
      (config['questions'] ?? []).map((q) => Map<String, dynamic>.from(q)),
    );
    _article = Map<String, dynamic>.from(widget.assignment['article'] ?? {});
  }

  static const List<String> _optionLabels = ['A', 'B', 'C', 'D'];

  bool _isChoice(Map<String, dynamic> q) {
    final options = q['options'];
    return q['type'] == 'single_choice' ||
        (options is List && options.isNotEmpty);
  }

  Future<void> _submit() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('還有 ${_questions.length - _answers.length} 題沒作答')),
      );
      return;
    }
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    final result = await ApiClient.submitAssignmentQuiz(
      userId: userId,
      assignmentId: widget.assignment['assignment_id'],
      answers: _answers.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['status'] == 'success') {
      await _showResultDialog(result);
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('繳交失敗：${result['error'] ?? '未知錯誤'}')),
      );
    }
  }

  Future<void> _showResultDialog(Map<String, dynamic> result) {
    final score = result['score'] ?? 0;
    final results = List<Map<String, dynamic>>.from(
      (result['results'] ?? []).map((r) => Map<String, dynamic>.from(r)),
    );
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              score >= 60 ? Icons.verified_rounded : Icons.edit_note_rounded,
              color: score >= 60 ? const Color(0xFF10B981) : Colors.orange,
              size: 56,
            ),
            const SizedBox(height: 8),
            Text('$score 分', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text(
              result['message'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (_, i) {
              final r = results[i];
              final ok = r['is_correct'] == true;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ok ? Icons.check_circle : Icons.cancel,
                      color: ok ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${r['question'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (!ok)
                          Text('正確答案：${r['correct_answer'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.red)),
                        if ((r['explanation'] ?? '').toString().isNotEmpty)
                          Text(r['explanation'],
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('回作業清單')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instructions = (widget.assignment['instructions'] ?? '').toString();
    final translation = (_article['translation'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
        title: Text(
          widget.assignment['title'] ?? '文章閱讀作業',
          style: const TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (instructions.isNotEmpty) ...[
            _card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(instructions, style: const TextStyle(height: 1.5))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _article['title'] ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  _article['content'] ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.9),
                ),
                if (translation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showTranslation = !_showTranslation),
                      icon: Icon(_showTranslation ? Icons.visibility_off : Icons.translate, size: 18),
                      label: Text(_showTranslation ? '隱藏翻譯' : '顯示翻譯'),
                    ),
                  ),
                  if (_showTranslation)
                    Text(translation,
                        style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.grey)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('閱讀測驗（${_questions.length} 題）',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (int i = 0; i < _questions.length; i++) ...[
            _buildQuestion(i, _questions[i]),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('送出作答', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(int index, Map<String, dynamic> q) {
    final List<String> choices = _isChoice(q)
        ? List<String>.from(q['options'] ?? [])
        : const ['O', 'X'];
    final bool isChoice = _isChoice(q);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${q['question'] ?? ''}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.5)),
          const SizedBox(height: 6),
          for (int j = 0; j < choices.length; j++)
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              value: isChoice ? _optionLabels[j] : choices[j],
              groupValue: _answers[index],
              title: Text(
                isChoice
                    ? '${_optionLabels[j]}. ${choices[j]}'
                    : (choices[j] == 'O' ? 'O  正確' : 'X  錯誤'),
              ),
              onChanged: (v) => setState(() => _answers[index] = v!),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: child,
      );
}

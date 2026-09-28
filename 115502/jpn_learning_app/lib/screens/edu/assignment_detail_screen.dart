import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/screens/sentence/sentence_practice_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';
import 'package:jpn_learning_app/screens/article/article_detail_screen.dart';
import 'package:jpn_learning_app/screens/edu/article_quiz_screen.dart';

/// 作業詳情：老師的話、題目要求、截止時間、繳交狀態，按「開始作答」才進練習畫面。
///
/// 資料來源：GET /api/assignment/<id>?user_id=
/// 有作答過就 pop(true)，讓清單回來時重新整理。
class AssignmentDetailScreen extends StatefulWidget {
  final int assignmentId;

  const AssignmentDetailScreen({Key? key, required this.assignmentId}) : super(key: key);

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  Map<String, dynamic>? _a;
  bool _isLoading = true;
  String? _error;
  bool _didPractice = false;

  static const Map<String, String> _typeLabels = {
    'sentence': '造句挑戰',
    'photo': '拍照學習',
    'chat': 'AI 對話',
    'article': '文章閱讀',
  };
  static const Map<String, IconData> _typeIcons = {
    'sentence': Icons.edit_note_rounded,
    'photo': Icons.photo_camera_outlined,
    'chat': Icons.chat_bubble_outline_rounded,
    'article': Icons.menu_book_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '請先登入';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ApiClient.getAssignmentDetail(widget.assignmentId, userId);
    if (!mounted) return;
    if (res['status'] == 'success') {
      setState(() {
        _a = Map<String, dynamic>.from(res['assignment'] ?? {});
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = res['error'] ?? '載入作業失敗';
      });
    }
  }

  // ---------- 導向作答畫面 ----------

  void _startPractice() {
    final a = _a!;
    final String type = a['task_type'] ?? '';
    final config = Map<String, dynamic>.from(a['config'] ?? {});
    final int id = widget.assignmentId;

    Widget? next;
    switch (type) {
      case 'sentence':
        next = SentencePracticeScreen(assignmentId: id);
        break;
      case 'photo':
        next = CameraScreen(assignmentId: id);
        break;
      case 'chat':
        final topic = (config['topic'] ?? '').toString();
        if (topic.isEmpty) {
          _hint('這份作業沒有設定對話情境，請聯絡老師');
          return;
        }
        next = RoleplayScreen(
          topicTitle: topic,
          characterName: '預設老師',
          assignmentId: id,
          minTurns: (config['min_turns'] as num?)?.toInt(),
          dialectId: (config['dialect_id'] as num?)?.toInt(),
        );
        break;
      case 'article':
        if (a['article'] == null) {
          _hint('找不到這份作業指定的文章，請聯絡老師');
          return;
        }
        final hasQuiz = config['has_quiz'] == true &&
            (config['questions'] as List?)?.isNotEmpty == true;
        next = hasQuiz
            ? ArticleQuizScreen(assignment: a)
            : ArticleDetailScreen(
                article: Article.fromJson(Map<String, dynamic>.from(a['article'])),
                assignmentId: id,
              );
        break;
      default:
        _hint('此題型尚未支援');
        return;
    }

    _didPractice = true;
    Navigator.push(context, MaterialPageRoute(builder: (_) => next!)).then((_) => _load());
  }

  void _hint(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- 顯示用 ----------

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// 依題型把老師的設定翻成學生看得懂的要求
  List<String> _requirements(String type, Map<String, dynamic> config, Map<String, dynamic>? article) {
    switch (type) {
      case 'sentence':
        final vocabs = List<String>.from(config['required_vocabs'] ?? []);
        return [
          if ((config['grammar_point'] ?? '').toString().isNotEmpty) '使用文法：${config['grammar_point']}',
          if (vocabs.isNotEmpty) '必須用到單字：${vocabs.join('、')}',
          if (config['pass_score'] != null) '及格分數：${config['pass_score']} 分',
        ];
      case 'photo':
        return [
          if ((config['theme'] ?? '').toString().isNotEmpty) '拍攝主題：${config['theme']}',
          if (config['min_vocab_count'] != null) '一張照片至少辨識出 ${config['min_vocab_count']} 個單字',
        ];
      case 'chat':
        return [
          if ((config['topic'] ?? '').toString().isNotEmpty) '對話情境：${config['topic']}',
          if (config['min_turns'] != null) '至少對話 ${config['min_turns']} 輪（只算你說的話）',
        ];
      case 'article':
        final n = (config['questions'] as List?)?.length ?? 0;
        return [
          if (article != null) '指定文章：${article['title'] ?? ''}',
          config['has_quiz'] == true && n > 0 ? '讀完後作答 $n 題測驗，系統自動閱卷' : '朗讀文章並完成 AI 評分',
        ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didPractice);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F7F5),
          elevation: 0,
          title: const Text('作業詳情',
              style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w900)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
        ),
        body: _buildBody(),
        bottomNavigationBar: _a == null ? null : _buildBottomButton(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      );
    }
    final a = _a!;
    final String type = a['task_type'] ?? '';
    final config = Map<String, dynamic>.from(a['config'] ?? {});
    final article = a['article'] is Map ? Map<String, dynamic>.from(a['article']) : null;
    final submission = Map<String, dynamic>.from(a['submission'] ?? {});
    final String status = submission['status'] ?? 'pending';
    final bool isPending = status == 'pending';
    final bool isOverdue = a['is_overdue'] == true;
    final instructions = (a['instructions'] ?? '').toString();
    final reqs = _requirements(type, config, article);
    final due = _formatDateTime(a['due_at']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // 標題區
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_typeIcons[type] ?? Icons.assignment_outlined, color: const Color(0xFF4A90E2)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title'] ?? '未命名作業',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _typeLabels[type] ?? type,
                        if ((a['classroom_name'] ?? '').toString().isNotEmpty) a['classroom_name'],
                      ].join(' · '),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      due.isEmpty ? '沒有截止時間' : '截止：$due${isPending && isOverdue ? '（已逾期）' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isPending && isOverdue ? Colors.red : Colors.grey,
                        fontWeight: isPending && isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 老師的話
        if (instructions.isNotEmpty) ...[
          _sectionTitle('老師的話'),
          _card(child: Text(instructions, style: const TextStyle(height: 1.6))),
          const SizedBox(height: 12),
        ],

        // 作業要求
        if (reqs.isNotEmpty) ...[
          _sectionTitle('作業要求'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in reqs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r, style: const TextStyle(height: 1.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 繳交狀態
        _sectionTitle('繳交狀態'),
        _buildSubmissionCard(status, submission),
      ],
    );
  }

  Widget _buildSubmissionCard(String status, Map<String, dynamic> s) {
    final score = s['score'];
    final comment = (s['teacher_comment'] ?? '').toString();
    final attempts = (s['attempt_count'] as num?)?.toInt() ?? 0;
    final submittedAt = _formatDateTime(s['submitted_at']);
    final bool isLate = s['is_late'] == true;

    String label;
    Color color;
    switch (status) {
      case 'graded':
        label = score != null ? '已批閱：$score 分' : '已批閱';
        color = const Color(0xFF10B981);
        break;
      case 'submitted':
        label = '已繳交，等老師批閱';
        color = const Color(0xFF4A90E2);
        break;
      default:
        label = '尚未繳交';
        color = Colors.orange;
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status == 'pending' ? Icons.pending_actions : Icons.assignment_turned_in_rounded, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          if (status != 'pending') ...[
            const SizedBox(height: 6),
            Text(
              [
                if (submittedAt.isNotEmpty) '繳交時間：$submittedAt${isLate ? '（逾期）' : ''}',
                if (attempts > 0) '作答 $attempts 次',
              ].join('　'),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('老師評語：$comment', style: const TextStyle(height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final status = (_a!['submission'] ?? const {})['status'] ?? 'pending';
    final bool isPending = status == 'pending';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _startPractice,
            icon: Icon(isPending ? Icons.play_arrow_rounded : Icons.replay_rounded),
            label: Text(isPending ? '開始作答' : '再做一次',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPending ? const Color(0xFF4A90E2) : Colors.white,
              foregroundColor: isPending ? Colors.white : const Color(0xFF4A90E2),
              side: isPending ? null : const BorderSide(color: Color(0xFF4A90E2)),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey)),
      );

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

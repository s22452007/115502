import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/sentence/sentence_practice_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';
import 'package:jpn_learning_app/screens/article/article_detail_screen.dart';
import 'package:jpn_learning_app/screens/edu/article_quiz_screen.dart';
import 'package:jpn_learning_app/models/article_model.dart';

/// 教育版學生的「我的作業」清單。
///
/// 資料來源：GET /api/assignment/my/<user_id>
/// 每筆欄位（見後端 student_assignment._assignment_json）：
///   assignment_id, classroom_name, title, task_type, due_at, is_overdue,
///   submission: { status: pending/submitted/graded, score, teacher_comment, ... }
class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({Key? key}) : super(key: key);

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  List<dynamic> _assignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
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

    try {
      final data = await ApiClient.getStudentAssignments(userId);
      if (!mounted) return;
      setState(() {
        _assignments = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '無法載入作業清單，請稍後再試';
      });
    }
  }

  // 依作業題型導向對應的練習畫面，並帶上 assignment_id；
  // 練習完成後後端會自動繳交，回到這裡再重新整理清單。
  Future<void> _navigateToPractice(Map<String, dynamic> assignment) async {
    final type = assignment['task_type'];
    final int? assignmentId = assignment['assignment_id'];
    if (assignmentId == null) return;

    Widget? nextScreen;
    switch (type) {
      case 'sentence':
        nextScreen = SentencePracticeScreen(assignmentId: assignmentId);
        break;
      case 'photo':
        nextScreen = CameraScreen(assignmentId: assignmentId);
        break;
      case 'chat':
      case 'article':
        // 這兩種需要老師設定的參數（對話情境 / 指定文章），先抓詳情
        nextScreen = await _buildDetailBasedScreen(type, assignmentId);
        break;
      default:
        _showHint('此題型尚未支援');
        return;
    }
    if (nextScreen == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => nextScreen!),
    ).then((_) => _fetchAssignments());
  }

  Future<Widget?> _buildDetailBasedScreen(String type, int assignmentId) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return null;

    final detail = await ApiClient.getAssignmentDetail(assignmentId, userId);
    if (detail['status'] != 'success') {
      _showHint('載入作業失敗：${detail['error'] ?? '未知錯誤'}');
      return null;
    }
    final a = Map<String, dynamic>.from(detail['assignment'] ?? {});
    final config = Map<String, dynamic>.from(a['config'] ?? {});

    if (type == 'chat') {
      final topic = (config['topic'] ?? '').toString();
      if (topic.isEmpty) {
        _showHint('這份作業沒有設定對話情境，請聯絡老師');
        return null;
      }
      return RoleplayScreen(
        topicTitle: topic,
        characterName: '預設老師',
        assignmentId: assignmentId,
        minTurns: (config['min_turns'] as num?)?.toInt(),
        dialectId: (config['dialect_id'] as num?)?.toInt(),
      );
    }

    // article
    if (a['article'] == null) {
      _showHint('找不到這份作業指定的文章，請聯絡老師');
      return null;
    }
    final hasQuiz = config['has_quiz'] == true &&
        (config['questions'] as List?)?.isNotEmpty == true;
    if (hasQuiz) {
      // 附測驗：讀文章 + 作答，送出後自動閱卷繳交
      return ArticleQuizScreen(assignment: a);
    }
    // 沒測驗：走一般朗讀流程，結算時自動繳交
    return ArticleDetailScreen(
      article: Article.fromJson(Map<String, dynamic>.from(a['article'])),
      assignmentId: assignmentId,
    );
  }

  void _showHint(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- 顯示用小工具 ----------

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

  /// 後端回傳 ISO 字串（老師設定的台灣時間），只取到分鐘顯示。
  String _formatDue(String? iso) {
    if (iso == null || iso.isEmpty) return '無截止日';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)} 截止';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的作業')),
      backgroundColor: const Color(0xFFF4F7F5),
      body: RefreshIndicator(
        onRefresh: _fetchAssignments,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _fetchAssignments, child: const Text('重試')),
          ),
        ],
      );
    }
    if (_assignments.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              '目前沒有派發的作業！\n太棒了！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.6),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final task = Map<String, dynamic>.from(_assignments[index]);
        final submission = Map<String, dynamic>.from(task['submission'] ?? {});
        final String status = submission['status'] ?? 'pending';
        final bool isPending = status == 'pending';
        final bool isOverdue = task['is_overdue'] == true;
        final score = submission['score'];
        final String type = task['task_type'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              isPending
                  ? (_typeIcons[type] ?? Icons.pending_actions)
                  : Icons.check_circle,
              color: isPending
                  ? (isOverdue ? Colors.red : Colors.orange)
                  : Colors.green,
              size: 32,
            ),
            title: Text(
              task['title'] ?? '未命名作業',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                if ((task['classroom_name'] ?? '').toString().isNotEmpty)
                  task['classroom_name'],
                _typeLabels[type] ?? type,
                _formatDue(task['due_at']),
                if (isPending && isOverdue) '已逾期',
              ].join(' · '),
              style: TextStyle(
                color: isPending && isOverdue ? Colors.red : null,
              ),
            ),
            isThreeLine: false,
            trailing: isPending
                ? ElevatedButton(
                    onPressed: () => _navigateToPractice(task),
                    child: const Text('前往作答'),
                  )
                : Text(
                    score != null
                        ? '$score 分'
                        : (status == 'graded' ? '已批閱' : '已繳交'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

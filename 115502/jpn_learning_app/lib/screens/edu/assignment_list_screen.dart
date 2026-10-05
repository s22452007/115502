import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/edu/assignment_detail_screen.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'package:jpn_learning_app/widgets/edu/assignment_tile.dart';

/// 教育版學生的「我的作業」清單。點任一筆進作業詳情，再從詳情「開始作答」。
///
/// 資料來源：GET /api/assignment/my/<user_id>（後端已排序：未交在前、截止近的優先）
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
      // 交了作業回到清單時，那份的截止提醒就會被取消
      NotificationService.scheduleAssignmentReminders(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '無法載入作業清單，請稍後再試';
      });
    }
  }

  void _openDetail(int assignmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: assignmentId)),
    ).then((_) => _fetchAssignments());
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
        final int? assignmentId = task['assignment_id'];
        return AssignmentTile(
          task: task,
          onTap: assignmentId == null ? null : () => _openDetail(assignmentId),
        );
      },
    );
  }
}

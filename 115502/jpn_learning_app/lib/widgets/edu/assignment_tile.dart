import 'package:flutter/material.dart';

/// 一筆作業的卡片：「我的作業」清單和教室頁的「作業」分頁共用。
///
/// [task] 是後端 student_assignment._assignment_json 的格式：
///   assignment_id, classroom_name, title, task_type, due_at, is_overdue, is_closed,
///   submission: { status: pending/submitted/graded, score, effective_score, ... }
class AssignmentTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onTap;

  /// 教室頁裡每筆都是同一班，不用再寫班名
  final bool showClassroom;

  const AssignmentTile({
    super.key,
    required this.task,
    this.onTap,
    this.showClassroom = true,
  });

  static const Map<String, String> typeLabels = {
    'sentence': '造句挑戰',
    'photo': '拍照學習',
    'chat': 'AI 對話',
    'article': '文章閱讀',
  };

  static const Map<String, IconData> typeIcons = {
    'sentence': Icons.edit_note_rounded,
    'photo': Icons.photo_camera_outlined,
    'chat': Icons.chat_bubble_outline_rounded,
    'article': Icons.menu_book_outlined,
  };

  /// 後端回傳 ISO 字串（老師設定的台灣時間），只取到分鐘顯示。
  static String formatDue(String? iso) {
    if (iso == null || iso.isEmpty) return '無截止日';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)} 截止';
  }

  @override
  Widget build(BuildContext context) {
    final submission = Map<String, dynamic>.from(task['submission'] ?? {});
    final String status = submission['status'] ?? 'pending';
    final bool isPending = status == 'pending';
    final bool isOverdue = task['is_overdue'] == true;
    final bool isClosed = task['is_closed'] == true;
    // 遲交扣分的作業顯示扣完、真正計入成績的分數
    final score = submission['effective_score'] ?? submission['score'];
    final String type = task['task_type'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isPending ? (typeIcons[type] ?? Icons.pending_actions) : Icons.check_circle,
          color: isPending ? (isOverdue ? Colors.red : Colors.orange) : Colors.green,
          size: 32,
        ),
        title: Text(
          task['title'] ?? '未命名作業',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            if (showClassroom && (task['classroom_name'] ?? '').toString().isNotEmpty)
              task['classroom_name'],
            typeLabels[type] ?? type,
            formatDue(task['due_at']),
            if (isPending && isOverdue) isClosed ? '已截止，不收遲交' : '已逾期',
          ].join(' · '),
          style: TextStyle(color: isPending && isOverdue ? Colors.red : null),
        ),
        trailing: isPending
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : Text(
                score != null ? '$score 分' : (status == 'graded' ? '已批閱' : '已繳交'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
      ),
    );
  }
}

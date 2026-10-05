import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/dialogs/join_classroom_dialog.dart';
import 'package:jpn_learning_app/widgets/edu/assignment_tile.dart';
import 'package:jpn_learning_app/screens/edu/classroom_detail_screen.dart';

class ClassroomListScreen extends StatefulWidget {
  const ClassroomListScreen({super.key});

  @override
  State<ClassroomListScreen> createState() => _ClassroomListScreenState();
}

class _ClassroomListScreenState extends State<ClassroomListScreen> {
  List<Map<String, dynamic>> _classrooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  /// [showSpinner] 為 false 時是下拉重新整理，畫面保留原本的清單，不換成轉圈圈
  Future<void> _loadClassrooms({bool showSpinner = true}) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _error = '無法取得學生資料';
        _isLoading = false;
      });
      return;
    }

    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final classrooms = await ApiClient.getMyClassrooms(userId);
      if (!mounted) return;
      setState(() {
        _classrooms = classrooms;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 後端有回錯誤原因（例如「請先登入」）就照實顯示；連不上、格式錯誤這類網路例外才用籠統的說法
      final text = e.toString();
      setState(() {
        _error = text.startsWith('Exception: ')
            ? text.replaceFirst('Exception: ', '')
            : '教室清單載入失敗，請稍後再試';
        _isLoading = false;
      });
    }
  }

  Future<void> _showJoinDialog() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final joined = await showDialog<bool>(
      context: context,
      builder: (_) => JoinClassroomDialog(studentId: userId),
    );
    if (joined == true) _loadClassrooms();
  }

  /// 點教室卡片進教室頁；回來時重新整理，讀過的公告紅點、交掉的作業數就會更新
  void _openClassroom(Map<String, dynamic> classroom) {
    if (classroom['classroom_id'] is! num) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassroomDetailScreen(classroom: classroom)),
    ).then((_) => _loadClassrooms(showSpinner: false));
  }

  /// 卡片上的待辦一行：「2 份待交 · 1 份已逾期 · 最近 10/5 23:59 截止」
  String _todoText(Map<String, dynamic> classroom) {
    final total = (classroom['assignment_count'] as num?)?.toInt() ?? 0;
    final pending = (classroom['pending_count'] as num?)?.toInt();
    final overdue = (classroom['overdue_count'] as num?)?.toInt() ?? 0;
    final nextDue = classroom['next_due_at']?.toString();
    if (total == 0) return '還沒有作業';
    if (pending == null) return '作業 $total 項'; // 舊版後端沒有待交數
    if (pending == 0) return '作業都交了';
    return [
      '$pending 份待交',
      if (overdue > 0) '$overdue 份已逾期',
      if (nextDue != null) '最近 ${AssignmentTile.formatDue(nextDue)}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: const Text('我的教室'),
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showJoinDialog,
        backgroundColor: AppColors.primaryLight2,
        icon: const Icon(Icons.add_home_work_outlined, color: Colors.white),
        label: const Text(
          '加入教室',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadClassrooms, child: const Text('重新載入')),
          ],
        ),
      );
    }
    if (_classrooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 56,
              color: AppColors.primaryLight2,
            ),
            SizedBox(height: 12),
            Text(
              '目前沒有已加入的教室',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // 下拉重新整理：老師剛發的公告，不用退出再進來就看得到紅點
    return RefreshIndicator(
      onRefresh: () => _loadClassrooms(showSpinner: false),
      child: ListView.separated(
        // 清單比螢幕短也要能下拉重新整理
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: _classrooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final classroom = _classrooms[index];
          final name = classroom['name']?.toString() ?? '未命名教室';
          final teacher = classroom['teacher_name']?.toString() ?? '老師';
          final unread = (classroom['unread_count'] as num?)?.toInt() ?? 0;

          return Material(
            color: AppColors.primaryLight2,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openClassroom(classroom),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '老師：$teacher',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _todoText(classroom),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(height: 3),
                            Text(
                              '$unread 則新公告',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

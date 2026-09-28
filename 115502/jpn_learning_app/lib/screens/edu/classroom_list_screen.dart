import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/dialogs/join_classroom_dialog.dart';

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

  Future<void> _loadClassrooms() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _error = '無法取得學生資料';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final classrooms = await ApiClient.getMyClassrooms(userId);
      if (!mounted) return;
      setState(() {
        _classrooms = classrooms;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '教室清單載入失敗，請稍後再試';
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: _classrooms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final classroom = _classrooms[index];
        final name = classroom['name']?.toString() ?? '未命名教室';
        final teacher = classroom['teacher_name']?.toString() ?? '老師';
        final assignmentCount = classroom['assignment_count'] as num?;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primaryLight2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
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
                    if (assignmentCount != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '作業 ${assignmentCount.toInt()} 項',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }
}

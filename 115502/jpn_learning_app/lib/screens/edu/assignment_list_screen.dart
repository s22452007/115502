import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
// 引入你的題型畫面
import 'package:jpn_learning_app/screens/sentence/sentence_practice_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
// import '閱讀與AI對話畫面...';

class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({Key? key}) : super(key: key);

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  List<dynamic> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      final data = await ApiClient.getStudentAssignments(userId);
      setState(() {
        _assignments = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // 錯誤處理
    }
  }

  // 根據作業類型導向不同的練習畫面，並攜帶 assignment_id (對應 Point 5)
  void _navigateToPractice(Map<String, dynamic> assignment) {
    final type = assignment['type']; // 假設後端有回傳題型：'sentence', 'photo', 'ai', 'reading'
    final assignmentId = assignment['id'];

    Widget nextScreen;
    switch (type) {
      case 'sentence':
        // ⚠️ 你需要修改 SentencePracticeScreen 的建構子，讓它可以接收 optional 的 assignmentId
        nextScreen = SentencePracticeScreen(assignmentId: assignmentId);
        break;
      case 'photo':
        nextScreen = CameraScreen(assignmentId: assignmentId);
        break;
      // case 'ai': ...
      // case 'reading': ...
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    ).then((_) => _fetchAssignments()); // 做完回來刷新清單
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的作業')),
      backgroundColor: const Color(0xFFF4F7F5),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _assignments.isEmpty
            ? const Center(child: Text('目前沒有派發的作業！\n太棒了！', textAlign: TextAlign.center))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assignments.length,
                itemBuilder: (context, index) {
                  final task = _assignments[index];
                  final isCompleted = task['is_completed'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        isCompleted ? Icons.check_circle : Icons.pending_actions,
                        color: isCompleted ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                      title: Text(task['title'] ?? '未命名作業', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('截止日期: ${task['deadline'] ?? '無'}'),
                      trailing: isCompleted 
                          ? Text('${task['score'] ?? 0} 分', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))
                          : ElevatedButton(
                              onPressed: () => _navigateToPractice(task),
                              child: const Text('前往作答'),
                            ),
                    ),
                  );
                },
              ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class SentenceHistoryScreen extends StatefulWidget {
  const SentenceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SentenceHistoryScreen> createState() => _SentenceHistoryScreenState();
}

class _SentenceHistoryScreenState extends State<SentenceHistoryScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = context.read<UserProvider>().userId ?? 8;
    final records = await ApiClient.getSentenceHistory(userId);
    if (mounted) setState(() { _records = records; _isLoading = false; });
  }

  Future<void> _claimPoints(int recordId, int points, int index) async {
    final userId = context.read<UserProvider>().userId ?? 8;
    final success = await ApiClient.claimSentencePoints(recordId, userId);
    
    if (success && mounted) {
      setState(() => _records[index]['is_claimed'] = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功領取 $points 點 J-pts！ 🎉'),
          backgroundColor: Colors.amber[700],
          behavior: SnackBarBehavior.floating,
        )
      );
      // 可在此呼叫 UserProvider 刷新總點數
    }
  }

  // 查看簡短評語的對話框
  void _showFeedbackDialog(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('評分：${record['score']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                const Text('📝 你的造句', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(record['user_sentence'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const Text('✨ 老師訂正', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(record['corrected_sentence'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 重點講評', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(record['ai_feedback'] ?? '表現不錯！', style: const TextStyle(height: 1.5)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: const Text('造句紀錄與獎勵', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final record = _records[index];
              final bool isClaimed = record['is_claimed'] ?? false;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => _showFeedbackDialog(record),
                  title: Text(record['grammar_point'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(record['user_sentence'], maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  trailing: isClaimed
                      ? const Icon(Icons.check_circle, color: Colors.grey, size: 30)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, elevation: 0),
                          onPressed: () => _claimPoints(record['id'], record['points_earned'], index),
                          child: Text('領取 ${record['points_earned']} 點', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                ),
              );
            },
          ),
    );
  }
}
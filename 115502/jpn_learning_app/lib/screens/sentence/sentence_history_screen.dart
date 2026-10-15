import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/widgets/dialogs/app_dialog.dart';

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
          content: Text('已領取 $points 點 J-pts'),
          backgroundColor: Colors.amber[700],
          behavior: SnackBarBehavior.floating,
        )
      );
      // 可在此呼叫 UserProvider 刷新總點數
    }
  }

  // 查看批改內容的對話框：與批改結果同一套分區（你的句子 → 參考句子 → 修改建議）
  void _showFeedbackDialog(Map<String, dynamic> record) {
    final sentence = (record['user_sentence'] ?? '').toString();
    final corrected = (record['corrected_sentence'] ?? '').toString();
    final feedback = (record['ai_feedback'] ?? '').toString().trim();

    AppDialog.message(
      context,
      title: '${record['grammar_point'] ?? ''}　${record['score']} 分',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('你的句子', first: true),
          Text(sentence, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textGrey)),
          if (corrected.isNotEmpty && corrected != sentence) ...[
            _label('參考句子'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(corrected,
                  style: const TextStyle(fontSize: 17, height: 1.5, color: AppColors.textDark)),
            ),
          ],
          if (feedback.isNotEmpty) ...[
            _label(corrected.isNotEmpty && corrected != sentence ? '修改建議' : '講評'),
            Text(feedback, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textDark)),
          ],
        ],
      ),
    );
  }

  static Widget _label(String text, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSubtle)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: AppColors.primary, size: AppIcons.navSize),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  // 校園教育版學生沒有點數獎勵，不顯示領取按鈕
                  trailing: context.read<UserProvider>().isEduStudent
                      ? null
                      : isClaimed
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
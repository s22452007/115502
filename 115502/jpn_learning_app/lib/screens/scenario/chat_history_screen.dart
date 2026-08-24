import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/widgets/common/furigana_text.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

/// AI 對話紀錄清單：列出過去每一場對話，點擊可接續聊下去。
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  Key _futureKey = UniqueKey();

  void _reload() => setState(() => _futureKey = UniqueKey());

  Future<void> _confirmDelete(int sessionId, String topic) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('刪除這場對話？'),
        content: Text('「$topic」的對話紀錄將永久刪除，無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final success = await ApiClient.deleteChatSession(sessionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? '已刪除這場對話' : '刪除失敗，請稍後再試'),
      backgroundColor: success ? null : Colors.redAccent,
    ));
    if (success) _reload();
  }

  void _openSession(Map<String, dynamic> s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleplayScreen(
          topicTitle: s['topic']?.toString() ?? '對話練習',
          characterName: s['character_name']?.toString() ?? '預設老師',
          resumeSessionId: (s['session_id'] as num).toInt(),
        ),
      ),
    ).then((_) => _reload()); // 聊完回來更新清單（訊息數、時間會變）
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return SubPageTemplate(
      title: 'AI 對話紀錄',
      body: userId == null
          ? const Center(
              child: Text('請先登入才能查看對話紀錄喔！',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : FutureBuilder<List<dynamic>>(
              key: _futureKey,
              future: ApiClient.fetchChatSessions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }

                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            '還沒有任何對話紀錄\n去和 AI 練習日語對話吧！',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = Map<String, dynamic>.from(sessions[index]);
                    return _buildSessionCard(s);
                  },
                );
              },
            ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    final topic = s['topic']?.toString() ?? '對話練習';
    final character = s['character_name']?.toString() ?? '';
    final dialect = s['dialect_name']?.toString() ?? '';
    // 訊息數是「使用者+AI」的總則數，換算成來回次數比較好懂
    final exchanges = ((s['message_count'] as num?)?.toInt() ?? 0) ~/ 2;
    // 預覽可能含 [漢字|假名] 標音，清掉再顯示
    final preview =
        FuriganaText.cleanFuriganaForTts(s['preview']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _openSession(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (character.isNotEmpty) character,
                          if (dialect.isNotEmpty) dialect,
                          '$exchanges 次來回',
                        ].join('・'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 22),
                  tooltip: '刪除這場對話',
                  onPressed: () =>
                      _confirmDelete((s['session_id'] as num).toInt(), topic),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s['last_message_at']?.toString() ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const Row(
                  children: [
                    Text('接續對話',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary, size: 20),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

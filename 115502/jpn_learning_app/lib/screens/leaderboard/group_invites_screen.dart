import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class GroupInvitesScreen extends StatefulWidget {
  const GroupInvitesScreen({Key? key}) : super(key: key);

  @override
  State<GroupInvitesScreen> createState() => _GroupInvitesScreenState();
}

class _GroupInvitesScreenState extends State<GroupInvitesScreen> {
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color beige = Color(0xFFF6EBC7);

  bool _isLoading = true;
  List<dynamic> _invites = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  // 📥 載入真實邀請名單
  Future<void> _loadInvites() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _isLoading = true);
    final result = await ApiClient.getGroupInvites(userId);

    if (mounted) {
      setState(() {
        if (result.containsKey('invites')) {
          _invites = result['invites'];
        }
        _isLoading = false;
      });
    }
  }

  // 📤 發送同意或拒絕的請求
  Future<void> _respondToInvite(int inviteId, String action, String groupName) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    // 🌟 新增：如果他按下「接受」，先跳出押金對賭警告窗！
    if (action == 'accept') {
      final bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚠️ 押金與額度提醒', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            '每週的第一個小組為免費參加。\n\n如果您本週已經免費參加過其他小組，本次接受邀請將會扣除 20 J-Pts 作為對賭押金（小組達標後退還）。\n\n確定要加入嗎？',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('先不要', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('確定加入', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ) ?? false;

      // 如果玩家按了「先不要」取消，就直接終止
      if (!confirm) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('處理中...'), duration: Duration(seconds: 1)),
    );

    final result = await ApiClient.respondGroupInvite(inviteId, action, userId);

    if (mounted) {
      if (result.containsKey('error')) {
        // 如果滿人或發生錯誤
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      } else {
        // 成功！
        final actionText = action == 'accept' ? '已接受' : '已拒絕';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$actionText「$groupName」的邀請')));

        if (action == 'accept') {
          // 如果是接受，代表已成功加入，直接回到上一頁 (上一頁的 .then 會觸發重新抓取公會資料)
          Navigator.pop(context);
        } else {
          // 如果是拒絕，留在本頁，重新抓取名單 (剛拒絕的邀請會消失)
          _loadInvites();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '小組邀請',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _invites.isEmpty
              ? const Center(
                  child: Text(
                    '目前沒有新的小組邀請',
                    style: TextStyle(
                      fontSize: 17,
                      color: subText,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  itemCount: _invites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _invites[index];
                    final inviteId = item['invite_id'];
                    final groupName = item['group_name'] ?? '未知小組';
                    final inviterName = item['inviter_name'] ?? '未知';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: beige),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '邀請人：$inviterName',
                            style: const TextStyle(
                              fontSize: 14,
                              color: subText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary.withOpacity(0.9),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => _respondToInvite(inviteId, 'accept', groupName),
                                  child: const Text(
                                    '接受',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: lightGreen,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => _respondToInvite(inviteId, 'reject', groupName),
                                  child: const Text(
                                    '拒絕',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
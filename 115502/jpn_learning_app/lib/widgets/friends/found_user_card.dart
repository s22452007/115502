import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class FoundUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isRequestSent;
  final VoidCallback onSendRequest;

  const FoundUserCard({
    Key? key,
    required this.user,
    required this.isRequestSent,
    required this.onSendRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color darkGreen = const Color(0xFF4A7A4D);
    final Color lightGreen = const Color(0xFFBFE1C3);

    final email = user['email'] as String? ?? '';
    final nickname = user['username'] ?? email.split('@').firstOrNull ?? 'User';
    final targetId = user['friend_id'] ?? '';
    final avatarBase64 = user['avatar'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // 跟側邊選單、好友列表用同一個頭像元件：顏色綁交友 ID、支援動物頭像
          UserAvatar(
            avatarBase64: avatarBase64,
            friendId: targetId.toString(),
            originalName: nickname.toString(),
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('@$targetId', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isRequestSent ? null : onSendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: isRequestSent ? Colors.grey.shade300 : darkGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              isRequestSent ? '已送出' : '加好友',
              style: TextStyle(color: isRequestSent ? Colors.grey.shade600 : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
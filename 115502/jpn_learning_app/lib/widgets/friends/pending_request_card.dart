import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class PendingRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PendingRequestCard({
    Key? key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color darkGreen = const Color(0xFF4A7A4D);
    
    final nickname = request['nickname'] ?? 'User';
    final friendId = request['friend_id'] ?? '';
    final avatarBase64 = request['avatar'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // 跟側邊選單、好友列表用同一個頭像元件：顏色綁交友 ID、支援動物頭像
          UserAvatar(
            avatarBase64: avatarBase64,
            friendId: friendId.toString(),
            originalName: nickname.toString(),
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('@$friendId', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: onReject),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: darkGreen, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.check, color: Colors.white), onPressed: onAccept),
          ),
        ],
      ),
    );
  }
}
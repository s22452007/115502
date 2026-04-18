import 'dart:convert';
import 'package:flutter/material.dart';

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

    // 計算預設頭像顏色
    final String safeName = nickname.isEmpty ? 'U' : nickname;
    int hash = 0;
    for (int i = 0; i < safeName.length; i++) {
      hash = (hash * 31 + safeName.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final List<String> colors = ['E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6', '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'];
    final String bgColor = colors[hash % colors.length];
    final String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(safeName)}&background=$bgColor&color=fff';

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
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            // 完美顯示 Base64 或預設圖片
            backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                ? (avatarBase64.startsWith('http')
                    ? NetworkImage(avatarBase64)
                    : MemoryImage(base64Decode(avatarBase64)) as ImageProvider)
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
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
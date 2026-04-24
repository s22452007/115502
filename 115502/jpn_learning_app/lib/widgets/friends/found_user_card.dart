import 'dart:convert';
import 'package:flutter/material.dart';

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
        color: lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: darkGreen.withOpacity(0.3)),
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
                    : MemoryImage(base64Decode(avatarBase64.split(",").last)) as ImageProvider)
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
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
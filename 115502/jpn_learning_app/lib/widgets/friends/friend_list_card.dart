import 'package:flutter/material.dart';
import 'dart:convert';

class FriendListCard extends StatelessWidget {
  final dynamic friend;
  final VoidCallback onMoreTap; // 當按下三點時觸發的動作

  const FriendListCard({
    Key? key,
    required this.friend,
    required this.onMoreTap,
  }) : super(key: key);

  // 取得專屬固定顏色
  String _getFixedColor(String name) {
    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB',
      '64B5F6', '4DD0E1', '4DB6AC', '81C784', 'AED581',
      'FFB74D', 'FF8A65',
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF4A7A4D);
    const Color lightGreen = Color(0xFFBFE1C3);

    if (friend == null || friend is! Map) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        color: Colors.red.shade100,
        child: Text('❌ 資料格式錯誤: $friend', style: const TextStyle(color: Colors.red)),
      );
    }

    final nickname = friend['nickname']?.toString() ?? 'Unknown';
    final friendId = friend['friend_id']?.toString() ?? '尚未產生';
    final String? avatarBase64 = friend['avatar']?.toString();
    const statusText = '一起開心學日文 📚';

    final String bgColor = _getFixedColor(nickname);
    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nickname)}&background=$bgColor&color=fff';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. 大頭貼
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                ? (avatarBase64.startsWith('http')
                    ? NetworkImage(avatarBase64)
                    : MemoryImage(base64Decode(avatarBase64)) as ImageProvider)
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
          ),
          const SizedBox(width: 16),
          
          // 2. 好友資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('@$friendId', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lightGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    statusText,
                    style: TextStyle(color: darkGreen, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 3. 右側的三點選單按鈕
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 28),
            onPressed: onMoreTap,
          ),
        ],
      ),
    );
  }
}
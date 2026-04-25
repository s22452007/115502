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

    if (friend == null || friend is! Map) return const SizedBox();

    final friendId = friend['friend_id']?.toString() ?? '尚未產生';
    final String? avatarBase64 = friend['avatar']?.toString();
    // 1. 取得名字資料
    final String originalName = friend['username']?.toString() ?? friend['original_name']?.toString() ?? '';
    final String? customNickname = friend['nickname']?.toString();

    // 2. 判斷邏輯
    final bool hasCustomNickname = customNickname != null && customNickname.trim().isNotEmpty;
    // 如果有自訂暱稱，主要顯示暱稱；如果沒有，就顯示原名；如果連原名都沒有，只好暫時顯示他的 ID
    final String displayName = hasCustomNickname ? customNickname : (originalName.isNotEmpty ? originalName : friendId);

    // 呼叫翻譯機，取得真實日語程度
    final String statusText = _getDisplayLevel(friend['japanese_level']?.toString());

    final String avatarText = originalName.isNotEmpty ? originalName : friendId;
    
    // 顏色也永遠綁定不變的 friendId
    final String bgColor = _getFixedColor(friendId);
    
    // 這樣一來，這串網址對同一個好友永遠長得一模一樣，絕對不會重新下載跟閃爍！
    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(avatarText)}&background=$bgColor&color=fff';
        
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
                    : MemoryImage(base64Decode(avatarBase64.split(",").last)) as ImageProvider)
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
          ),
          const SizedBox(width: 16),
          
          // 2. 好友資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 主要顯示的名字 (字體較大、粗體)
                Text(
                  displayName, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                ),
                const SizedBox(height: 4),

                // 如果有設定暱稱，底下多一行淡淡的括號顯示「原名」
                if (hasCustomNickname && originalName.isNotEmpty) ...[
                  Text(
                    '($originalName)', 
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)
                  ),
                  const SizedBox(height: 2),
                ],

                // 顯示專屬 ID
                Text('@$friendId', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                const SizedBox(height: 8),

                // 狀態標籤
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
import 'package:flutter/material.dart';
// 1. 記得引入我們的高級共用頭貼積木
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class GroupInfoCard extends StatelessWidget {
  final String groupName;
  final List<dynamic> members;

  const GroupInfoCard({
    Key? key,
    required this.groupName,
    required this.members,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color cardColor = Color(0xFFE8DCAA); // 排行榜的金黃色

    String hostName = '無';
    for (var m in members) {
      if (m['is_host'] == true) {
        hostName = m['nickname'] ?? '未知';
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(groupName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              // 如果這個位置有真實成員，就畫他的頭貼
              if (index < members.length) {
                final member = members[index];
                
                // 2. 取出該成員的資料 (我們剛才在後端 API 已經打包進去了)
                final String friendId = member['friend_id']?.toString() ?? '';
                final String originalName = member['username']?.toString() ?? member['nickname']?.toString() ?? '未知';
                final String? avatarBase64 = member['avatar']?.toString();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  // 3. 呼叫 UserAvatar，取代原本的 CircleAvatar！
                  child: UserAvatar(
                    avatarBase64: avatarBase64,
                    friendId: friendId,
                    originalName: originalName,
                    radius: 21,
                  ),
                );
              } 
              // 如果是空位，就畫灰色的 ➕ 號
              else {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const CircleAvatar(
                    radius: 21,
                    backgroundColor: Colors.white54,
                    child: Icon(Icons.add, color: Colors.black38),
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 12),
          Text('成員 ${members.length}/5 ・ 組長：$hostName', style: const TextStyle(fontSize: 14, color: subText)),
        ],
      ),
    );
  }
}
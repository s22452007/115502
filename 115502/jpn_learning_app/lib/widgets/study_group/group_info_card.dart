import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class GroupInfoCard extends StatelessWidget {
  final String groupName;
  final List<dynamic> members;
  final List<dynamic> pendingInvites; // 1. 新增這個參數

  const GroupInfoCard({
    Key? key,
    required this.groupName,
    required this.members,
    this.pendingInvites = const [], // 預設為空陣列
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color cardColor = Color(0xFFE8DCAA); // 排行榜的金黃色

    String hostName = '無';
    for (var m in members) {
      if (m['is_host'] == true) {
        hostName = m['nickname'] ?? m['username'] ?? '未知';
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
              // 狀況 1：正式成員 (畫正常頭貼)
              if (index < members.length) {
                final member = members[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: UserAvatar(
                    avatarBase64: member['avatar']?.toString(),
                    friendId: member['friend_id']?.toString() ?? '',
                    originalName: member['username']?.toString() ?? '未知',
                    radius: 21,
                  ),
                );
              } 
              // 狀況 2：邀請中的人 (畫半透明頭貼)
              else if (index < members.length + pendingInvites.length) {
                final pendingIndex = index - members.length;
                final pendingUser = pendingInvites[pendingIndex];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  // 用 Opacity 把他變半透明，暗示他還沒正式加入
                  child: Opacity(
                    opacity: 0.4, 
                    child: UserAvatar(
                      avatarBase64: pendingUser['avatar']?.toString(),
                      friendId: pendingUser['friend_id']?.toString() ?? '',
                      originalName: pendingUser['username']?.toString() ?? '未知',
                      radius: 21,
                    ),
                  ),
                );
              } 
              // 狀況 3：沒人邀的空位 (畫加號)
              else {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(
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
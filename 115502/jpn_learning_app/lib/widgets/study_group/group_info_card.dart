import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class GroupInfoCard extends StatelessWidget {
  final String groupName;
  final List<dynamic> members;
  final List<dynamic> pendingInvites;

  const GroupInfoCard({
    Key? key,
    required this.groupName,
    required this.members,
    this.pendingInvites = const [], 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color cardColor = Color(0xFFE8DCAA); 

    String hostName = '無';
    for (var m in members) {
      if (m['is_host'] == true) {
        hostName = m['nickname'] ?? m['username'] ?? '未知';
        break;
      }
    }

    // 處理下方的提示文字：如果有邀請中的人，就明確寫出來
    String memberCountText = '成員 ${members.length}/5';
    if (pendingInvites.isNotEmpty) {
      memberCountText += ' (邀請中 ${pendingInvites.length})';
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
              
              // 狀況 1：正式成員 (正常顯示)
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
              
              // 狀況 2：邀請中的人 (半透明 + 等待徽章)
              else if (index < members.length + pendingInvites.length) {
                final pendingIndex = index - members.length;
                final pendingUser = pendingInvites[pendingIndex];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  // 使用 Stack 來把小圖示疊在頭貼右下角
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: 0.4, 
                        child: UserAvatar(
                          avatarBase64: pendingUser['avatar']?.toString(),
                          friendId: pendingUser['friend_id']?.toString() ?? '',
                          originalName: pendingUser['username']?.toString() ?? '未知',
                          radius: 21,
                        ),
                      ),
                      // 新增：右下角的等待中 (時鐘) 徽章
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                          ),
                          child: const Icon(Icons.access_time, size: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                );
              } 
              
              // 狀況 3：空位 (顯示加號)
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
          // 把更新後的文字顯示在這裡
          Text('$memberCountText ・ 組長：$hostName', style: const TextStyle(fontSize: 14, color: subText)),
        ],
      ),
    );
  }
}
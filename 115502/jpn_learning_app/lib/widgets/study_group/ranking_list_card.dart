import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 引入我們的共用積木與工具箱
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';
import 'package:jpn_learning_app/utils/helpers.dart';

class RankingListCard extends StatelessWidget {
  final List<dynamic> members;
  final String type;

  const RankingListCard({
    Key? key,
    required this.members,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);

    final sortedMembers = List<dynamic>.from(members);
    
    sortedMembers.sort((a, b) {
      int valA = 0, valB = 0;
      if (type == 'scans') { valA = a['group_scans'] ?? 0; valB = b['group_scans'] ?? 0; }
      else if (type == 'points') { valA = a['group_points'] ?? 0; valB = b['group_points'] ?? 0; }
      else if (type == 'logins') { valA = a['group_logins'] ?? 0; valB = b['group_logins'] ?? 0; }
      return valB.compareTo(valA);
    });

    String unit = '次';
    if (type == 'points') unit = '點';
    if (type == 'logins') unit = '天';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('本週貢獻排行', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark)),
          ),
          ...List.generate(sortedMembers.length, (index) {
            final item = sortedMembers[index];
            final nickname = item['nickname']?.toString() ?? 'Unknown';
            final friendId = item['friend_id']?.toString() ?? '';
            final avatarBase64 = item['avatar']?.toString();
            
            // 取出程度並翻譯
            final String statusText = AppHelpers.getDisplayLevel(item['japanese_level']?.toString());
            
            int score = 0;
            if (type == 'scans') score = item['group_scans'] ?? 0;
            if (type == 'points') score = item['group_points'] ?? 0;
            if (type == 'logins') score = item['group_logins'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // 將需要的資料傳給內部的 Row
              child: _RankRow(
                rank: '${index + 1}', 
                name: nickname, 
                friendId: friendId,
                avatarBase64: avatarBase64,
                statusText: statusText,
                points: '$score $unit'
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final String rank;
  final String name;
  final String friendId;
  final String? avatarBase64;
  final String statusText;
  final String points;

  const _RankRow({
    required this.rank, 
    required this.name, 
    required this.friendId,
    required this.avatarBase64,
    required this.statusText,
    required this.points
  });

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF4A7A4D);
    const Color lightGreen = Color(0xFFBFE1C3);

    return Row(
      children: [
        CircleAvatar(radius: 14, backgroundColor: AppColors.primaryLighter, child: Text(rank, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13))),
        const SizedBox(width: 12),
        
        // 原本的灰色人頭變成我們的高級共用頭貼！
        UserAvatar(
          avatarBase64: avatarBase64,
          friendId: friendId,
          originalName: name,
          radius: 20,
        ),
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 16, color: Color(0xFF333333), fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              // 加上小小的程度標籤
              Text(statusText, style: TextStyle(fontSize: 11, color: darkGreen, fontWeight: FontWeight.bold)),
            ],
          )
        ),
        Text(points, style: const TextStyle(fontSize: 15, color: Color(0xFF6E6E6E), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
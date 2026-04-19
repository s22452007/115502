import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

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
              if (index < members.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.primaryLighter,
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                );
              } else {
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
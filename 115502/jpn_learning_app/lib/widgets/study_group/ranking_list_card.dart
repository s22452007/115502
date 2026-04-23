import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

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
    
    // 🌟 關鍵修復 1：排序時，讀取小組專屬的 group_ 系列變數
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
            final nickname = item['nickname'] ?? 'Unknown';
            
            // 🌟 關鍵修復 2：顯示分數時，也讀取 group_ 系列變數
            int score = 0;
            if (type == 'scans') score = item['group_scans'] ?? 0;
            if (type == 'points') score = item['group_points'] ?? 0;
            if (type == 'logins') score = item['group_logins'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RankRow(rank: '${index + 1}', name: nickname, points: '$score $unit'),
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
  final String points;

  const _RankRow({required this.rank, required this.name, required this.points});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 16, backgroundColor: AppColors.primaryLighter, child: Text(rank, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        CircleAvatar(radius: 18, backgroundColor: AppColors.primaryLighter, child: Icon(Icons.person, size: 18, color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 16, color: Color(0xFF333333), fontWeight: FontWeight.w700))),
        Text(points, style: const TextStyle(fontSize: 15, color: Color(0xFF6E6E6E), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
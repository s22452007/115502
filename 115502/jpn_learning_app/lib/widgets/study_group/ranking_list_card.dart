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
    
    sortedMembers.sort((a, b) {
      int valA = 0, valB = 0;
      if (type == 'scans') { valA = a['daily_scans'] ?? 0; valB = b['daily_scans'] ?? 0; }
      else if (type == 'points') { valA = a['j_pts'] ?? 0; valB = b['j_pts'] ?? 0; }
      else if (type == 'logins') { valA = a['streak_days'] ?? 0; valB = b['streak_days'] ?? 0; }
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
            
            int score = 0;
            if (type == 'scans') score = item['daily_scans'] ?? 0;
            if (type == 'points') score = item['j_pts'] ?? 0;
            if (type == 'logins') score = item['streak_days'] ?? 0;

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
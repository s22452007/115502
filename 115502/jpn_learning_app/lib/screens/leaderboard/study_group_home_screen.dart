import 'package:flutter/material.dart';
import 'invite_group_members_screen.dart';

class StudyGroupHomeScreen extends StatelessWidget {
  const StudyGroupHomeScreen({Key? key}) : super(key: key);

  static const Color green = Color(0xFF4E8B4C);
  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color beige = Color(0xFFF6EBC7);
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color bgColor = Color(0xFFF7F7F7);

  @override
  Widget build(BuildContext context) {
    final members = [
      {'name': '林美伶', 'points': 1200},
      {'name': '張宏豪', 'points': 950},
      {'name': '你', 'points': 600},
      {'name': '陳玟柔', 'points': 250},
    ];

    const int goal = 5000;
    const int current = 3000;
    final double progress = current / goal;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: green,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Study Group',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              '管理',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          _groupInfoCard(),
          const SizedBox(height: 16),
          _goalCard(progress: progress, current: current, goal: goal),
          const SizedBox(height: 16),
          _rankingCard(members),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  text: '提醒隊友',
                  filled: true,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已提醒隊友繼續學習')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  text: '邀請成員',
                  filled: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InviteGroupMembersScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupInfoCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            '日文衝刺小組',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _MemberAvatar(),
              SizedBox(width: 8),
              _MemberAvatar(),
              SizedBox(width: 8),
              _MemberAvatar(),
              SizedBox(width: 8),
              _MemberAvatar(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '成員 4/5 ・ 組長：林美伶',
            style: TextStyle(
              fontSize: 14,
              color: subText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard({
    required double progress,
    required int current,
    required int goal,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: beige,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本週共同目標',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$current / $goal points',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 16,
              backgroundColor: const Color(0xFFD9E6D3),
              valueColor: const AlwaysStoppedAnimation<Color>(green),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '還差 2000 points ・ 截止時間：週日 23:59',
            style: TextStyle(
              fontSize: 14,
              color: subText,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '完成目標後全員可獲得額外獎勵',
            style: TextStyle(
              fontSize: 14,
              color: textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingCard(List<Map<String, dynamic>> members) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本週貢獻排行',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(members.length, (index) {
            final item = members[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: lightGreen,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${item['points']} pts',
                    style: const TextStyle(
                      fontSize: 15,
                      color: subText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? green : lightGreen,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: filled ? Colors.white : green,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar();

  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color green = Color(0xFF4E8B4C);

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 22,
      backgroundColor: lightGreen,
      child: Icon(Icons.person, color: green),
    );
  }
}
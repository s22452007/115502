import 'package:flutter/material.dart';
import 'invite_group_members_screen.dart';

class StudyGroupHomeScreen extends StatelessWidget {
  final Map<String, dynamic> groupData; // 接收後端傳來的公會資料

  const StudyGroupHomeScreen({Key? key, required this.groupData}) : super(key: key);

  static const Color green = Color(0xFF4E8B4C);
  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color beige = Color(0xFFF6EBC7);
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color bgColor = Color(0xFFF7F7F7);

  @override
  Widget build(BuildContext context) {
    // 1. 從後端資料解包成員名單
    final String groupName = groupData['group_name'] ?? 'Study Group';
    final List<dynamic> members = groupData['members'] ?? [];

    // 2. 算出總進度 (大家今日拍照次數的總和)
    int totalScans = 0;
    for (var m in members) {
      totalScans += (m['daily_scans'] as int? ?? 0);
    }

    final int goal = 15; // 假設公會每日目標是 15 次拍照
    final double progress = (totalScans / goal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: green,
        elevation: 0,
        centerTitle: true,
        title: Text(
          groupName,
          style: const TextStyle(
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
          _groupInfoCard(groupName, members), // 🌟 傳入真實資料
          const SizedBox(height: 16),
          _goalCard(progress: progress, current: totalScans, goal: goal), // 🌟 傳入真實進度
          const SizedBox(height: 16),
          _rankingCard(members), // 🌟 傳入名單做排行
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

  // --- 更新：接收群組名稱與成員名單 ---
  Widget _groupInfoCard(String groupName, List<dynamic> members) {
    // 找誰是組長
    String hostName = '無';
    for (var m in members) {
      if (m['is_host'] == true) {
        hostName = m['nickname'] ?? '未知';
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            groupName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              // 顯示成員頭像，最多 5 個位置
              if (index < members.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: lightGreen,
                    child: Icon(Icons.person, color: green),
                  ),
                );
              } else {
                // 還沒滿 5 人顯示空位
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(Icons.add, color: Colors.grey),
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '成員 ${members.length}/5 ・ 組長：$hostName',
            style: const TextStyle(
              fontSize: 14,
              color: subText,
            ),
          ),
        ],
      ),
    );
  }

  // --- 更新：目標卡片 ---
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
            '今日共同目標', 
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$current / $goal 次拍照',
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
          Text(
            '還差 ${goal - current > 0 ? goal - current : 0} 次 ・ 截止時間：今日 23:59',
            style: const TextStyle(
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

  // --- 更新：貢獻排行 ---
  Widget _rankingCard(List<dynamic> members) {
    // 幫成員依據拍照進度進行排序
    final sortedMembers = List<dynamic>.from(members);
    sortedMembers.sort((a, b) {
      int scansA = a['daily_scans'] as int? ?? 0;
      int scansB = b['daily_scans'] as int? ?? 0;
      return scansB.compareTo(scansA); // 數字大的排前面
    });

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
            '今日貢獻排行', 
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(sortedMembers.length, (index) {
            final item = sortedMembers[index];
            final nickname = item['nickname'] ?? 'Unknown';
            final scans = item['daily_scans'] ?? 0;
            
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
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: lightGreen,
                    child: Icon(Icons.person, size: 18, color: green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        color: textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$scans 次',
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
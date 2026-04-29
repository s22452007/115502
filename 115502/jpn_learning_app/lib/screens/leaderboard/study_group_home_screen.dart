import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/invite_group_members_screen.dart';
import 'package:jpn_learning_app/widgets/study_group/group_info_card.dart';
import 'package:jpn_learning_app/widgets/study_group/goal_progress_card.dart';
import 'package:jpn_learning_app/widgets/study_group/ranking_list_card.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class StudyGroupHomeScreen extends StatelessWidget {
  final Map<String, dynamic> groupData;
  final bool showAppBar;

  const StudyGroupHomeScreen({
    Key? key,
    required this.groupData,
    this.showAppBar = true,
  }) : super(key: key);

  static const Color subText = Color(0xFF6E6E6E);

  @override
  Widget build(BuildContext context) {
    final String groupName = groupData['group_name'] ?? '學習小組';
    final List<dynamic> members = groupData['members'] ?? [];

    final String goalType = groupData['goal_type'] ?? 'scans';
    final int goalTarget = groupData['goal_target'] ?? 30;
    final int rewardPoints = groupData['reward_points'] ?? 50;
    final int groupId = groupData['group_id'] ?? 0;

    final int currentTotal = groupData['current_progress'] as int? ?? 0;
    final double progress = (currentTotal / goalTarget).clamp(0.0, 1.0);

    Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // 🧱 積木 1：小組資訊
          GroupInfoCard(
            groupName: groupData['group_name'],
            members: groupData['members'] ?? [],
            pendingInvites: groupData['pending_invites'] ?? [], 
          ),
          const SizedBox(height: 16),

          // 🧱 積木 2：進度與領獎
          GoalProgressCard(
            progress: progress,
            current: currentTotal,
            goal: goalTarget,
            type: goalType,
            rewardPoints: rewardPoints,
            groupId: groupId,
          ),
          const SizedBox(height: 16),

          // 🧱 積木 3：排行榜
          RankingListCard(members: members, type: goalType),
          const SizedBox(height: 18),

          // 底部動作按鈕
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已提醒隊友繼續學習！')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '提醒隊友',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      final int? currentGroupId = groupData['group_id'] as int?;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InviteGroupMembersScreen(groupId: currentGroupId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLighter,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '邀請成員',
                      style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (!showAppBar) return bodyContent;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F2),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
        title: Text(
          groupName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // 退出按鈕已經被消滅了！這裡不留任何後路！
      ),
      body: bodyContent,
    );
  }
}
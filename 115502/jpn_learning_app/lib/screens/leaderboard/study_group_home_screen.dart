import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'invite_group_members_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'group_config_screen.dart'; 

class StudyGroupHomeScreen extends StatelessWidget {
  final Map<String, dynamic> groupData;
  final bool showAppBar; // 控制是否顯示頂部導覽列

  const StudyGroupHomeScreen({
    Key? key, 
    required this.groupData,
    this.showAppBar = true,
  }) : super(key: key);

  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color cardColor = Color(0xFFE8DCAA); // 排行榜的金黃色

  @override
  Widget build(BuildContext context) {
    final String groupName = groupData['group_name'] ?? 'Study Group';
    final List<dynamic> members = groupData['members'] ?? [];

    // 依據你的資料結構，這裡算每日拍照總數當作目標進度
    int currentPoints = 0;
    for (var m in members) {
      currentPoints += (m['daily_scans'] as int? ?? 0); // 假設用 scans 代替 points
    }
    final int goal = 15; // 假設公會目標
    final double progress = (currentPoints / goal).clamp(0.0, 1.0);

    Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildGroupInfoCard(groupName, members),
          const SizedBox(height: 16),
          _buildGoalCard(progress: progress, current: currentPoints, goal: goal),
          const SizedBox(height: 16),
          _buildRankingCard(members),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已提醒隊友繼續學習')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('提醒隊友', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      // 1. 從 groupData 中把 group_id 拿出來 (確保轉成整數 int)
                      // 如果你的後端回傳的 key 叫別的名字 (例如 'id')，請把 'group_id' 換掉
                      final int? currentGroupId = groupData['group_id'] as int?;

                      // 2. 跳轉時，把 currentGroupId 傳過去 (記得要把原本的 const 拿掉！)
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupConfigScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLighter,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text('邀請成員', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          groupName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // 新增退出按鈕在這！
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
            tooltip: '退出小組',
            onPressed: () => _showLeaveGroupDialog(context, groupData['group_id']),
          ),
        ],
      ),
      body: bodyContent,
    );
  }


  Widget _buildGroupInfoCard(String groupName, List<dynamic> members) {
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
                  child: CircleAvatar(radius: 21, backgroundColor: AppColors.primaryLighter, child: Icon(Icons.person, color: AppColors.primary)),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(radius: 21, backgroundColor: Colors.white54, child: const Icon(Icons.add, color: Colors.black38)),
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

  Widget _buildGoalCard({required double progress, required int current, required int goal}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本週共同目標', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 14),
          Text('$current / $goal 次拍照', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress, minHeight: 16, backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text('還差 ${goal - current > 0 ? goal - current : 0} 次 ・ 截止時間：週日 23:59', style: const TextStyle(fontSize: 14, color: subText)),
          const SizedBox(height: 10),
          const Text('完成目標後全員可獲得額外獎勵', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
        ],
      ),
    );
  }

  Widget _buildRankingCard(List<dynamic> members) {
    final sortedMembers = List<dynamic>.from(members);
    sortedMembers.sort((a, b) => (b['daily_scans'] as int? ?? 0).compareTo(a['daily_scans'] as int? ?? 0));

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
            final scans = item['daily_scans'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RankRow(rank: '${index + 1}', name: nickname, points: '$scans 次'),
            );
          }),
        ],
      ),
    );
  }
  // ==========================
  // 🌟 這裡新增：退出小組的彈出對話框邏輯
  // ==========================
  void _showLeaveGroupDialog(BuildContext context, dynamic groupId) {
    if (groupId == null) return;
    final int validGroupId = groupId as int;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出小組', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('確定要退出這個學習小組嗎？\n\n⚠️ 如果你是組長，退出將會直接解散整個小組喔！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // 關閉對話框
            child: const Text('取消', style: TextStyle(color: subText, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx); // 先關閉對話框
              
              final userId = context.read<UserProvider>().userId;
              if (userId == null) return;

              // 顯示 Loading
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在處理中...')));

              // 呼叫退出 API
              final result = await ApiClient.leaveGroup(validGroupId, userId);

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (result.containsKey('error')) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
                } else {
                  // 成功退出
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '已退出小組')));
                  
                  // 退回上一頁 (大廳)，並傳回 true 告訴前一頁需要重整
                  Navigator.pop(context, true); 
                }
              }
            },
            child: const Text('確定退出', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
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
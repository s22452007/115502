// 1. Flutter 核心套件
import 'package:flutter/material.dart';

// 2. 第三方套件
import 'package:provider/provider.dart';

// 3. App 畫面 (Screens)
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/invite_group_members_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';

// 4. 狀態管理 (Providers)
import 'package:jpn_learning_app/providers/user_provider.dart';

// 5. 工具與常數 (Utils / Constants)
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

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
    final String groupName = groupData['group_name'] ?? '學習小組';
    final List<dynamic> members = groupData['members'] ?? [];
    
    // 從後端取得目標設定 (如果沒有就給預設值防呆)
    final String goalType = groupData['goal_type'] ?? 'scans';
    final int goalTarget = groupData['goal_target'] ?? 30;

    final int rewardPoints = groupData['reward_points'] ?? 50;
    final int groupId = groupData['group_id'] ?? 0;

    // 動態計算目前的總進度
    int currentTotal = 0;
    for (var m in members) {
      if (goalType == 'scans') {
        currentTotal += (m['daily_scans'] as int? ?? 0);
      } else if (goalType == 'points') {
        currentTotal += (m['j_pts'] as int? ?? 0);
      } else if (goalType == 'logins') {
        currentTotal += (m['streak_days'] as int? ?? 0);
      }
    }
    
    // 限制進度條最高只能到 1.0 (100%)
    final double progress = (currentTotal / goalTarget).clamp(0.0, 1.0);

    Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildGroupInfoCard(groupName, members),
          const SizedBox(height: 16),
          
          // 把動態算好的變數傳進去給目標卡片 (加了 context 才能跳視窗) 👇
          _buildGoalCard(
            context,
            progress: progress, 
            current: currentTotal, 
            goal: goalTarget, 
            type: goalType,
            rewardPoints: rewardPoints,
            groupId: groupId,
          ),
          
          const SizedBox(height: 16),
          // 排行榜也根據目標類型來排序！
          _buildRankingCard(members, goalType),
          const SizedBox(height: 18),
          
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已提醒隊友繼續學習！')));
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
                      final int? currentGroupId = groupData['group_id'] as int?;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InviteGroupMembersScreen(groupId: currentGroupId), 
                        ),
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

  // 動態顯示單位與文案
  Widget _buildGoalCard(BuildContext context, {required double progress, required int current, required int goal, required String type, required int rewardPoints, required int groupId}) {
    String unit = '次拍照';
    if (type == 'points') unit = 'J-Pts';
    if (type == 'logins') unit = '天登入';

    // 判斷是否達標
    bool isGoalReached = current >= goal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // 如果達標，背景變成亮金黃色慶祝！
        color: isGoalReached ? Colors.amber.shade100 : cardColor, 
        borderRadius: BorderRadius.circular(20)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGoalReached ? "🏆 小組任務大成功！" : "🎯 本週共同目標", 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark)
          ),
          const SizedBox(height: 14),
          
          // ==== 狀態 A：還沒達標，顯示進度條 ====
          if (!isGoalReached) ...[
            Text('$current / $goal $unit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress, minHeight: 16, backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text('還差 ${goal - current} ${unit.replaceAll('拍照', '').replaceAll('登入', '')} ・ 截止時間：週日 23:59', style: const TextStyle(fontSize: 14, color: subText)),
            const SizedBox(height: 10),
            const Text('完成目標後全員可獲得額外獎勵', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
          ],

          // ==== 狀態 B：達標了，顯示領獎按鈕！ ====
          if (isGoalReached) ...[
            const Text('太棒了！你們已經達成目標！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.card_giftcard, size: 24),
                label: Text("領取 $rewardPoints 點並結業！", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600, // 金色按鈕
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  // 1. 跳出恭喜獲得獎勵的視窗
                  showDialog(
                    context: context,
                    barrierDismissible: false, // 點旁邊不能關掉
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text("🎉 恭喜達標！", style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text("你們小組超棒的！系統已將 $rewardPoints 點發送至你的錢包！\n\n領取後將退出小組，準備迎接下一個挑戰吧！", style: const TextStyle(fontSize: 16, height: 1.5)),
                      actions: [
                        TextButton(
                          child: const Text("太棒了！", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final userId = context.read<UserProvider>().userId;
                            if (userId == null) return;
                            
                            // 改成呼叫剛剛寫的領獎 API！
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('發送點數中...')));
                            final result = await ApiClient.claimReward(groupId, userId);
                            
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            
                            // 確保畫面還在，再執行關閉視窗的動作
                            if (context.mounted) {
                              if (result.containsKey('error')) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
                              } else {
                                // 🎉 領獎成功！
                                final userProvider = context.read<UserProvider>();
                                userProvider.setJPts(userProvider.jPts + rewardPoints);

                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '成功領取獎勵！')));
                                
                                // 關閉對話框，並回到沒有小組的首頁
                                Navigator.of(ctx).pop(); 
                                Navigator.of(context).pop(); 
                              }
                            }
                          },
                        )
                      ]
                    ),
                  );
                },
              ),
            )
          ],
        ],
      ),
    );
  }

  // 排行榜動態排序與顯示
  Widget _buildRankingCard(List<dynamic> members, String type) {
    final sortedMembers = List<dynamic>.from(members);
    
    // 根據目前的任務類型來排序
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
            
            // 抓取對應的分數
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
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('取消', style: TextStyle(color: subText, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx); 
              
              final userId = context.read<UserProvider>().userId;
              if (userId == null) return;

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在處理中...')));

              final result = await ApiClient.leaveGroup(validGroupId, userId);

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (result.containsKey('error')) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '已退出小組')));
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudyGroupScreen()),
                      );
                    }
                  });
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
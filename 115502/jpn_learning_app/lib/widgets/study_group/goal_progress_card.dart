import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class GoalProgressCard extends StatelessWidget {
  final double progress;
  final int current;
  final int goal;
  final String type;
  final int rewardPoints;
  final int groupId;

  // 因為領完就直接退出了，所以不需要 hasClaimed 來判斷灰底狀態了！
  const GoalProgressCard({
    Key? key,
    required this.progress,
    required this.current,
    required this.goal,
    required this.type,
    required this.rewardPoints,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color cardColor = Color(0xFFE8DCAA);

    String unit = '次拍照';
    if (type == 'points') unit = 'J-Pts';
    if (type == 'logins') unit = '天登入';

    bool isGoalReached = current >= goal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isGoalReached ? Colors.amber.shade100 : cardColor, 
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGoalReached ? "🏆 小組任務大成功！" : "🎯 本週共同目標", 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark)
          ),
          const SizedBox(height: 14),
          
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
            const Text('完成目標後，可各自領取獎勵！', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
          ],

          if (isGoalReached) ...[
            const Text('太棒了！你們已經達成目標！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              // 達標後一律顯示金黃色的領獎按鈕
              child: ElevatedButton.icon(
                icon: const Icon(Icons.card_giftcard, size: 24),
                label: Text("領取 $rewardPoints 點並結業！", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600, 
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正在向伺服器驗證並領取獎勵...'))
                  );

                  final userId = context.read<UserProvider>().userId;
                  if (userId == null) return;

                  final result = await ApiClient.claimReward(groupId, userId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();

                    if (result.containsKey('error')) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
                    } else {
                      // 後端認證成功，更新錢包餘額！
                      if (result.containsKey('new_j_pts')) {
                        context.read<UserProvider>().setJPts(result['new_j_pts']);
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text("🎉 恭喜達標！", style: TextStyle(fontWeight: FontWeight.bold)),
                          content: Text(result['message'] ?? '領取成功！你已順利從小組結業！', style: const TextStyle(fontSize: 16, height: 1.5)),
                          actions: [
                            TextButton(
                              child: const Text("太棒了！", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.of(ctx).pop(); 
                                // 領完獎直接退出小組畫面，回到大廳
                                Navigator.of(context).popUntil((route) => route.isFirst); 
                              },
                            )
                          ],
                        ),
                      );
                    }
                  }
                },
              ),
            )
          ]
        ],
      ),
    );
  }
}
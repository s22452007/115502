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
            const Text('完成目標後全員可獲得額外獎勵', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
          ],

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
                  backgroundColor: Colors.amber.shade600, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text("🎉 恭喜達標！", style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text("你們小組超棒的！系統已將 $rewardPoints 點發送至你的錢包！\n\n領取後將退出小組，準備迎接下一個挑戰吧！", style: const TextStyle(fontSize: 16, height: 1.5)),
                      actions: [
                        TextButton(
                          child: const Text("太棒了！", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            // 1. 先顯示 Loading 狀態，去問後端是不是真的達標了
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('正在向伺服器驗證任務進度...'))
                            );

                            final userId = context.read<UserProvider>().userId;
                            if (userId == null) return;

                            // 打 API 討獎勵
                            final result = await ApiClient.claimReward(groupId, userId);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();

                            if (context.mounted) {
                              if (result.containsKey('error')) {
                                // 2. 後端無情打臉：顯示錯誤，絕對不開香檳
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result['error']))
                                );
                              } else {
                                // 3. 後端認證成功：加點數，這時候才彈出慶祝對話框！🎉
                                final userProvider = context.read<UserProvider>();
                                userProvider.setJPts(userProvider.jPts + rewardPoints);

                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text("🎉 恭喜達標！", style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: Text("你們小組超棒的！系統已將 $rewardPoints 點發送至你的錢包！\n\n領取後將退出小組，準備迎接下一個挑戰吧！", style: const TextStyle(fontSize: 16, height: 1.5)),
                                    actions: [
                                      TextButton(
                                        child: const Text("太棒了！", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.of(ctx).pop(); // 關閉慶祝彈窗
                                          Navigator.of(context).pop(); // 退出小組畫面，回到上一頁
                                        },
                                      )
                                    ],
                                  ),
                                );
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
}
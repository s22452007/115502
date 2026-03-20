import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class GroupInvitesScreen extends StatefulWidget {
  const GroupInvitesScreen({Key? key}) : super(key: key);

  @override
  State<GroupInvitesScreen> createState() => _GroupInvitesScreenState();
}

class _GroupInvitesScreenState extends State<GroupInvitesScreen> {
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color beige = Color(0xFFF6EBC7);

  final List<Map<String, String>> invites = [
    {
      'groupName': '日文衝刺小組',
      'owner': '林美伶',
      'members': '3/5',
      'goal': '每週共同達成 5000 points',
    },
    {
      'groupName': '美語學習小組',
      'owner': '張宏豪',
      'members': '4/5',
      'goal': '每日一起完成 AI 對話',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '小組邀請',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: invites.isEmpty
          ? const Center(
              child: Text(
                '目前沒有新的小組邀請',
                style: TextStyle(
                  fontSize: 17,
                  color: subText,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              itemCount: invites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = invites[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: beige),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['groupName']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '邀請人：${item['owner']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: subText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '目前人數：${item['members']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: subText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['goal']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: subText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.9),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已接受「${item['groupName']}」邀請'),
                                  ),
                                );
                              },
                              child: const Text(
                                '接受',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lightGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  invites.removeAt(index);
                                });
                              },
                              child: const Text(
                                '拒絕',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
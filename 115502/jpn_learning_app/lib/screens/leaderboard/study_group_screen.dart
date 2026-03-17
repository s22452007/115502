import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class StudyGroupScreen extends StatelessWidget {
  // 🌟 用來接收上一頁傳來的好友資料
  final List<Map<String, String>> members;

  // 🌟 建構子加上 members 參數，這樣上一頁才能把資料丟進來
  const StudyGroupScreen({Key? key, this.members = const []}) : super(key: key);

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
        title: const Icon(Icons.camera_alt, color: Colors.white),
        centerTitle: true,
        actions: const [
          Icon(Icons.person_outline, color: Colors.white),
          SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardYellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'study group',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  // 🌟 動態生成 5 個圓圈與好友頭像
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      // 1. 判斷這個位置有沒有好友
                      bool hasMember = index < members.length;

                      // 2. 🛡️ 安全檢查：判斷這個好友有沒有 'avatar' 這個欄位，且不是空的
                      bool hasAvatar =
                          hasMember &&
                          members[index].containsKey('avatar') &&
                          members[index]['avatar'] != null &&
                          members[index]['avatar']!.isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryLighter,
                          // 🌟 安全寫法：確定有大頭貼才用 NetworkImage，沒有就給 null
                          backgroundImage: hasAvatar
                              ? NetworkImage(members[index]['avatar']!)
                              : null,
                          // 🌟 如果沒有大頭貼，就顯示預設的人頭 Icon
                          child: hasAvatar
                              ? null
                              : Icon(Icons.person, color: AppColors.primary),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Shared Goal: 5000 points',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '3000/5000',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.85),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Remind Teammates',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

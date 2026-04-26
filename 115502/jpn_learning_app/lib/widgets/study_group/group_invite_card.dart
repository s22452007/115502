import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 引入共用積木
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class GroupInviteCard extends StatelessWidget {
  final String groupName;
  final String inviterName;
  // 新增這三個參數來接後端傳來的新資料
  final String inviterFriendId;
  final String? inviterAvatar;
  final String inviterLevelText; // 這個是在外層先用 AppHelpers 翻譯好的
  
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const GroupInviteCard({
    Key? key,
    required this.groupName,
    required this.inviterName,
    required this.inviterFriendId,
    required this.inviterAvatar,
    required this.inviterLevelText,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color lightGreen = Color(0xFFEAF3E3);
    const Color beige = Color(0xFFF6EBC7);
    const Color darkGreen = Color(0xFF4A7A4D);

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
          // 小組名稱
          Text(groupName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 12),
          
          // 全新設計：邀請人資訊列 (頭貼 + 名字 + 標籤)
          Row(
            children: [
              UserAvatar(
                avatarBase64: inviterAvatar,
                friendId: inviterFriendId,
                originalName: inviterName,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('邀請人：$inviterName', style: const TextStyle(fontSize: 14, color: subText, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(inviterLevelText, style: TextStyle(fontSize: 11, color: darkGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          // 下方的接受拒絕按鈕
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onAccept,
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
                  onPressed: onReject,
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
  }
}
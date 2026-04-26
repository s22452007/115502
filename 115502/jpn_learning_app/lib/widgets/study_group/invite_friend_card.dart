import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/helpers.dart';

class InviteFriendCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onToggleInvite;
  final VoidCallback onCancelInvite;

  const InviteFriendCard({
    Key? key,
    required this.friend,
    required this.onToggleInvite,
    required this.onCancelInvite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color lightGreen = Color(0xFFEAF3E3);
    const Color beige = Color(0xFFF6EBC7);
    const Color darkGreen = Color(0xFF4A7A4D);

    final String avatarBase64 = friend['avatar']?.toString() ?? '';
    final String friendId = friend['id']?.toString() ?? '未知ID';
    
    final String originalName = friend['username']?.toString() ?? friend['name']?.toString() ?? '';
    final String? customNickname = friend['nickname']?.toString();
    final bool hasCustomNickname = customNickname != null && customNickname.trim().isNotEmpty;
    final String displayName = hasCustomNickname ? customNickname : (originalName.isNotEmpty ? originalName : friendId);

    // 呼叫翻譯機，取得真實日語程度
    final String statusText = AppHelpers.getDisplayLevel(friend['japanese_level']?.toString());

    final String avatarText = originalName.isNotEmpty ? originalName : friendId;
    final String bgColor = AppHelpers.getFixedColor(friendId);
    final String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(avatarText)}&background=$bgColor&color=fff';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: beige),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (avatarBase64.isNotEmpty)
                ? (avatarBase64.startsWith('http') ? NetworkImage(avatarBase64) : MemoryImage(base64Decode(avatarBase64.split(",").last)) as ImageProvider)
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark)),
                const SizedBox(height: 4),
                if (hasCustomNickname && originalName.isNotEmpty) ...[
                  Text('($originalName)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  const SizedBox(height: 2),
                ],
                Text('@$friendId', style: const TextStyle(fontSize: 14, color: subText)),
                const SizedBox(height: 8),
                
                // 把程度標籤也印在邀請卡片上！
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: TextStyle(color: darkGreen.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          _buildActionButton(context, lightGreen),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Color lightGreen) {
    const Color subText = Color(0xFF6E6E6E);
    
    // 狀況 1：對方已經有小組了 (灰色不能按)
    if (friend['has_group'] == true) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: null,
        child: const Text('已有小組', style: TextStyle(color: subText, fontWeight: FontWeight.w700)),
      );
    } 
    // 狀況 2：已經發送邀請給對方 (換成紅色的取消按鈕！)
    else if (friend['is_invited'] == true) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white, // 白底
          foregroundColor: Colors.redAccent, // 紅字
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 1.5), // 紅色邊框
          ),
        ),
        onPressed: onCancelInvite, // 記得綁定取消邀請的動作
        child: const Text('取消邀請', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    } 
    // 狀況 3：選取準備要邀請的人 (淺綠色)
    else if (friend['invited'] == true) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: lightGreen, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: onToggleInvite,
        child: const Text('已選取', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      );
    } 
    // 狀況 4：還沒邀請的人 (深綠色)
    else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.9), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: onToggleInvite,
        child: const Text('邀請', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
    }
  }
}
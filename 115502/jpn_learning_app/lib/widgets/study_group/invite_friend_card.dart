import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class InviteFriendCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onToggleInvite;

  const InviteFriendCard({
    Key? key,
    required this.friend,
    required this.onToggleInvite,
  }) : super(key: key);

  String _getFixedColor(String name) {
    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6',
      '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);
    const Color lightGreen = Color(0xFFEAF3E3);
    const Color beige = Color(0xFFF6EBC7);

    final String avatarBase64 = friend['avatar']?.toString() ?? '';
    final String nickname = friend['name']?.toString() ?? 'Unknown';
    final String friendId = friend['id']?.toString() ?? '未知ID';

    final String bgColor = _getFixedColor(nickname);
    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nickname)}&background=$bgColor&color=fff';

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
                ? (avatarBase64.startsWith('http')
                    ? NetworkImage(avatarBase64)
                    : MemoryImage(base64Decode(avatarBase64)) as ImageProvider)
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark)),
                const SizedBox(height: 4),
                Text('@$friendId', style: const TextStyle(fontSize: 14, color: subText)),
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

    if (friend['has_group'] == true) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: null,
        child: const Text('已有小組', style: TextStyle(color: subText, fontWeight: FontWeight.w700)),
      );
    } else if (friend['is_invited'] == true) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightGreen,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: null,
        child: const Text('已邀請', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      );
    } else if (friend['invited'] == true) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightGreen,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onToggleInvite,
        child: const Text('已選取', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      );
    } else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary.withOpacity(0.9),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onToggleInvite,
        child: const Text('邀請', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
    }
  }
}
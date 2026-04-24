import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarBase64;
  final String? friendId;
  final String originalName;
  final double radius;

  const UserAvatar({
    Key? key,
    required this.avatarBase64,
    required this.friendId,
    required this.originalName,
    this.radius = 26,
  }) : super(key: key);

  String _getFixedColor(String hashString) {
    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6',
      '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'
    ];
    int hash = 0;
    for (int i = 0; i < hashString.length; i++) {
      hash = (hash * 31 + hashString.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // 1. 如果有 ID 就用 ID 算顏色，否則退回用名字算
    final String hashString = friendId?.isNotEmpty == true ? friendId! : originalName;
    final String bgColor = _getFixedColor(hashString);
    
    // 2. 文字永遠用原名顯示
    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(originalName)}&background=$bgColor&color=fff';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: (avatarBase64 != null && avatarBase64!.isNotEmpty)
          ? (avatarBase64!.startsWith('http')
              ? NetworkImage(avatarBase64!)
              : MemoryImage(base64Decode(avatarBase64!)) as ImageProvider)
          : NetworkImage(defaultAvatarUrl) as ImageProvider,
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';

// 預設可愛動物頭像 (emoji → 背景色)
const Map<String, Color> kAvatarPresets = {
  '🐱': Color(0xFFFFAB91),
  '🐶': Color(0xFFFFCC80),
  '🐼': Color(0xFFCFD8DC),
  '🐨': Color(0xFF80DEEA),
  '🐸': Color(0xFFA5D6A7),
  '🦊': Color(0xFFFFB74D),
  '🐰': Color(0xFFF48FB1),
  '🐻': Color(0xFFBCAAA4),
  '🐯': Color(0xFFFFD54F),
  '🐮': Color(0xFFDCE775),
  '🦁': Color(0xFFFFE082),
  '🐧': Color(0xFF80CBC4),
  '🐙': Color(0xFFCE93D8),
  '🦋': Color(0xFFB39DDB),
  '🐢': Color(0xFF80CBC4),
  '🦄': Color(0xFFF8BBD9),
};

class UserAvatar extends StatelessWidget {
  final String? avatarBase64;
  final String? friendId;
  final String originalName;
  final double radius;
  final bool isPremium;

  const UserAvatar({
    Key? key,
    required this.avatarBase64,
    required this.friendId,
    required this.originalName,
    this.radius = 26,
    this.isPremium = false,
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

    // 優先：emoji 預設頭像
    if (avatarBase64 != null && kAvatarPresets.containsKey(avatarBase64)) {
      final bgColor = kAvatarPresets[avatarBase64]!;
      Widget emojiCircle = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Center(
          child: Text(
            avatarBase64!,
            style: TextStyle(fontSize: radius * 0.95),
          ),
        ),
      );
      if (!isPremium) return emojiCircle;
      final badgeSize = (radius * 0.52).clamp(10.0, 20.0);
      return Stack(clipBehavior: Clip.none, children: [
        emojiCircle,
        _premiumBadge(badgeSize),
      ]);
    }

    ImageProvider imageProvider;
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      if (avatarBase64!.startsWith('http')) {
        imageProvider = NetworkImage(avatarBase64!);
      } else {
        try {
          final raw = avatarBase64!.contains(',')
              ? avatarBase64!.substring(avatarBase64!.indexOf(',') + 1)
              : avatarBase64!;
          imageProvider = MemoryImage(base64Decode(raw));
        } catch (_) {
          imageProvider = NetworkImage(defaultAvatarUrl);
        }
      }
    } else {
      imageProvider = NetworkImage(defaultAvatarUrl);
    }

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: imageProvider,
    );

    if (!isPremium) return avatar;

    final badgeSize = (radius * 0.52).clamp(10.0, 20.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [avatar, _premiumBadge(badgeSize)],
    );
  }

  Widget _premiumBadge(double size) => Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
              color: Color(0xFFC6B13B), shape: BoxShape.circle),
          child: Icon(Icons.workspace_premium,
              color: Colors.white, size: size * 0.65),
        ),
      );
}
import 'dart:convert';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final bool isGuest;
  final String userName;
  final String? userAvatar;
  final String rawLevel;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;
  final String Function(String?) getDisplayLevel;

  const ProfileHeader({
    Key? key,
    required this.isGuest,
    required this.userName,
    required this.userAvatar,
    required this.rawLevel,
    required this.onAvatarTap,
    required this.onNameTap,
    required this.getDisplayLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = const Color(0xFF333333);
    final primaryGreen = const Color.fromARGB(255, 74, 124, 89);
    
    // 計算預設頭像顏色
    final String safeName = userName.isEmpty ? 'Guest' : userName;
    int hash = 0;
    for (int i = 0; i < safeName.length; i++) {
      hash = (hash * 31 + safeName.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final List<String> colors = ['E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6', '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'];
    final String bgColor = colors[hash % colors.length];
    final String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(safeName)}&background=$bgColor&color=fff';

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFC5E1A5),
                  backgroundImage: (userAvatar != null && userAvatar!.isNotEmpty)
                      ? (userAvatar!.startsWith('http') ? NetworkImage(userAvatar!) : MemoryImage(base64Decode(userAvatar!)) as ImageProvider)
                      : NetworkImage(defaultAvatarUrl) as ImageProvider,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: isGuest ? null : onNameTap,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        isGuest ? '訪客' : userName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isGuest) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(isGuest ? '登入解鎖更多功能' : getDisplayLevel(rawLevel), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: isGuest ? 0.0 : 0.3,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(primaryGreen),
                  minHeight: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
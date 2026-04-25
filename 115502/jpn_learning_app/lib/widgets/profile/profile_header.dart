import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';
import 'package:jpn_learning_app/utils/helpers.dart';

class ProfileHeader extends StatelessWidget {
  final bool isGuest;
  final String userName;
  final String? friendId; // 這個參數：為了給 UserAvatar 算顏色
  final String? userAvatar;
  final String rawLevel;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;

  const ProfileHeader({
    Key? key,
    required this.isGuest,
    required this.userName,
    this.friendId, 
    required this.userAvatar,
    required this.rawLevel,
    required this.onAvatarTap,
    required this.onNameTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = const Color(0xFF333333);
    final primaryGreen = const Color.fromARGB(255, 74, 124, 89);
    
    // 💡 我們已經把計算顏色的邏輯交給 UserAvatar 積木處理了，
    // 所以這裡不需要再寫那些 hash 跟 colors 的陣列囉！

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              // 這是原本的白色邊框跟陰影
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1), 
                      blurRadius: 8, 
                      offset: const Offset(0, 3)
                    )
                  ],
                ),
                // 呼叫我們寫好的共用積木！
                child: UserAvatar(
                  avatarBase64: userAvatar,
                  friendId: friendId,      // 傳入專屬 ID 確保顏色不變
                  originalName: userName,  // 傳入名字當作預設文字
                  radius: 40,              // 保持原本的 40 大小
                ),
              ),
              // 右下角的相機小圖示
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
              Text(isGuest ? '登入解鎖更多功能' : AppHelpers.getDisplayLevel(rawLevel), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
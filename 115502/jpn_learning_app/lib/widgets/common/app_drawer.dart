import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.username ?? '使用者';
    final userEmail = userProvider.email ?? '';
    final avatarUrl = userProvider.avatar;

    return Drawer(
      backgroundColor: _flatCanvasColor,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌟 Commit 2: 沉浸式頁首
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 30),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryLighter,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, size: 30, color: AppColors.primary) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(fontSize: 12, color: _subTextColor, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/profile/system_settings_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userAvatar = userProvider.avatar;
    final userEmail = userProvider.email ?? 'guest@example.com';
    final userName = userProvider.username ?? userEmail.split('@')[0];
    final friendId = userProvider.friendId;
    final bool isGuest = userProvider.userId == null;

    final List<String> colors = ['E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6', '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'];
    final String hashString = friendId?.toString() ?? userName;
    int hash = 0;
    for (int i = 0; i < hashString.length; i++) hash = (hash * 31 + hashString.codeUnitAt(i)) & 0x7FFFFFFF;
    final String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=${colors[hash % colors.length]}&color=fff';

    return Drawer(
      backgroundColor: _flatCanvasColor,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 頁首區：與主頁高度一致
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 30),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryLighter,
                  backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                      ? (userAvatar.startsWith('http') ? NetworkImage(userAvatar) : MemoryImage(base64Decode(userAvatar.split(",").last)) as ImageProvider)
                      : NetworkImage(defaultAvatarUrl) as ImageProvider,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isGuest ? '訪客' : userName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _textColor, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(isGuest ? '登入解鎖更多功能！' : 'ID：${friendId ?? '—'}', style: TextStyle(fontSize: 13, color: _subTextColor, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. 功能清單列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMenuItem(context, Icons.home_outlined, '回首頁', onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
                }),
                _buildMenuItem(context, Icons.person_outline, '個人檔案', onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }),
                _buildMenuItem(context, Icons.bookmark_border, '我的單字探險', onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()));
                }),
                _buildMenuItem(context, Icons.people_outline, '好友', onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsListScreen()));
                }),
                _buildMenuItem(context, Icons.groups_outlined, '我的學習小組', onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen()));
                }),
                _buildMenuItem(
                  context, 
                  Icons.stars, 
                  '訂閱與點數', 
                  color: Colors.orange, 
                  bgColor: Colors.orange.withOpacity(0.08),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                  }
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16), child: Divider(color: Colors.black12, thickness: 0.5)),
                _buildMenuItem(context, Icons.settings_outlined, '系統設定', onTap: () {
                  Navigator.pop(context);
                  Future.delayed(Duration.zero, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen()));
                  });
                }),
              ],
            ),
          ),

          const Spacer(),

          // 3. 底部區域：登入與登出 (藥丸按鈕樣式)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: _buildMenuItem(
              context, 
              isGuest ? Icons.login : Icons.logout, 
              isGuest ? '註冊 / 登入' : '登出帳號',
              color: isGuest ? Colors.blue : Colors.redAccent,
              bgColor: isGuest ? Colors.blue.withOpacity(0.08) : Colors.redAccent.withOpacity(0.08),
              onTap: () {
                Navigator.pop(context); 
                if (!isGuest) context.read<UserProvider>().logout();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {required VoidCallback onTap, Color? color, Color? bgColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: bgColor ?? Colors.transparent, borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: color ?? _textColor, size: 24),
        title: Text(title, style: TextStyle(color: color ?? _textColor, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
      ),
    );
  }
}
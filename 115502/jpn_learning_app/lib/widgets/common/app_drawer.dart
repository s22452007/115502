import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/profile/system_settings_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.username ?? '使用者';
    final friendId = userProvider.friendId;
    final isGuest = !userProvider.isLoggedIn;

    return Drawer(
      backgroundColor: _flatCanvasColor,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 30),
            child: Row(
              children: [
                UserAvatar(
                  avatarBase64: userProvider.avatar,
                  friendId: friendId,
                  originalName: userName,
                  radius: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isGuest ? '訪客' : userName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _textColor)),
                      const SizedBox(height: 4),
                      Text(isGuest ? '登入解鎖功能' : 'ID：${friendId ?? '—'}', style: TextStyle(fontSize: 13, color: _subTextColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildPillItem(context, Icons.home_outlined, '回首頁', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()))),
                  _buildPillItem(context, Icons.person_outline, '個人檔案', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                  _buildPillItem(context, Icons.bookmark_border, '單字探險', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()))),
                  _buildPillItem(context, Icons.people_outline, '好友', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsListScreen()))),
                  _buildPillItem(context, Icons.groups_outlined, '學習小組', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen()))),
                  _buildPillItem(context, Icons.stars, '訂閱與點數', color: Colors.orange, bgColor: Colors.orange.withOpacity(0.1), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()))),
                  const Divider(height: 30, thickness: 0.5),
                  _buildPillItem(context, Icons.settings_outlined, '系統設定', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen()))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            child: _buildPillItem(
              context, 
              isGuest ? Icons.login : Icons.logout, 
              isGuest ? '註冊 / 登入' : '登出帳號',
              color: isGuest ? Colors.blue : Colors.redAccent,
              bgColor: isGuest ? Colors.blue.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              onTap: () {
                if (!isGuest) userProvider.logout();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem(BuildContext context, IconData icon, String title, {VoidCallback? onTap, Color? color, Color? bgColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap ?? () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color ?? _textColor, size: 24),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: TextStyle(color: color ?? _textColor, fontWeight: FontWeight.w800, fontSize: 15))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
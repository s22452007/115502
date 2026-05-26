import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/profile/system_settings_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
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
                  isPremium: userProvider.isPremium,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest ? '訪客' : userName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isGuest ? '登入解鎖功能' : 'ID：${friendId ?? '—'}',
                        style: TextStyle(fontSize: 13, color: _subTextColor),
                      ),
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
                  //iconColor: AppColors.primary (文字會自動預設為黑色)
                  _buildPillItem(
                    context,
                    Icons.home_outlined,
                    '回首頁',
                    iconColor: AppColors.primary,
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    ),
                  ),
                  _buildPillItem(
                    context,
                    Icons.person_outline,
                    '個人檔案',
                    iconColor: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                  _buildPillItem(
                    context,
                    Icons.bookmark_border,
                    '單字探險',
                    iconColor: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ResultGalleryV2Screen(),
                      ),
                    ),
                  ),
                  _buildPillItem(
                    context,
                    Icons.people_outline,
                    '好友',
                    iconColor: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FriendsListScreen(),
                      ),
                    ),
                  ),
                  _buildPillItem(
                    context,
                    Icons.groups_outlined,
                    '學習小組',
                    iconColor: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudyGroupScreen(),
                      ),
                    ),
                  ),
                  _buildPillItem(
                    context,
                    Icons.storefront,
                    '商城與會員中心',
                    iconColor: Colors.orange,
                    textColor: Colors.orange, // 保持商城按鈕的跳色
                    bgColor: Colors.orange.withOpacity(0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const StoreDashboardScreen(initialIndex: 0),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 30, thickness: 0.5),
                  _buildPillItem(
                    context,
                    Icons.settings_outlined,
                    '系統設定',
                    // 沒有傳入 iconColor，所以 Icon 也是預設黑色
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SystemSettingsScreen(),
                      ),
                    ),
                  ),
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
              iconColor: isGuest ? Colors.blue : Colors.redAccent,
              textColor: isGuest ? Colors.blue : Colors.redAccent, // 保持登出按鈕的跳色
              bgColor: isGuest
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.redAccent.withOpacity(0.1),
              onTap: () {
                if (!isGuest) userProvider.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 將 color 拆分為 iconColor 與 textColor
  Widget _buildPillItem(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
    Color? iconColor, // 控制 Icon 顏色
    Color? textColor, // 控制 文字 顏色
    Color? bgColor,   // 控制 背景 顏色
  }) {
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
                // 🌟 Icon 使用 iconColor，沒給的話就用預設的 _textColor
                Icon(icon, color: iconColor ?? _textColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      // 🌟 文字使用 textColor，沒給的話就用預設的 _textColor (黑色)
                      color: textColor ?? _textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    // ==========================================
    // 1. 取得與整理使用者資料
    // ==========================================
    final userProvider = context.watch<UserProvider>();
    final userAvatar = userProvider.avatar;
    final userEmail = userProvider.email ?? 'guest@example.com';
    final userName = userProvider.username ?? userEmail.split('@')[0];
    final friendId = userProvider.friendId;
    
    final bool isGuest = userProvider.userId == null;

    // ==========================================
    // 2. 計算預設頭貼 (確保與好友列表顏色統一)
    // ==========================================
    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6',
      '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65',
    ];

    // 使用恆定不變的 friendId 來計算顏色，如果沒有 ID (訪客) 才退回使用名字
    final String hashString = friendId?.toString() ?? userName;
    int hash = 0;
    for (int i = 0; i < hashString.length; i++) {
      hash = (hash * 31 + hashString.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final String bgColor = colors[hash % colors.length];

    // 頭貼的「文字」顯示名字，但「背景顏色」綁定絕對不變的 ID
    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=$bgColor&color=fff';

    // ==========================================
    // 3. 構建側邊欄 UI
    // ==========================================
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- 區塊 A：頂部個人資訊 Header ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: const Color.fromARGB(255, 74, 124, 89),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                        ? (userAvatar.startsWith('http')
                            ? NetworkImage(userAvatar)
                            : MemoryImage(base64Decode(userAvatar)) as ImageProvider)
                        : NetworkImage(defaultAvatarUrl) as ImageProvider,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isGuest ? '訪客' : userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest ? '登入解鎖更多功能！' : 'ID：${friendId ?? '—'}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // --- 區塊 B：主要功能導覽列 ---
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('回首頁', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('個人檔案', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('我的單字探險', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('好友', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('我的學習小組', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyGroupScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.stars, color: Colors.orange),
            title: const Text(
              '訂閱與點數',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
          ),

          const Divider(),

          // --- 區塊 C：系統設定與登出 ---
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('系統設定', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemSettingsScreen()),
                );
              });
            },
          ),
          ListTile(
            leading: Icon(
              isGuest ? Icons.login : Icons.logout,
              color: isGuest ? Colors.blue : Colors.redAccent,
            ),
            title: Text(
              isGuest ? '註冊 / 登入' : '登出',
              style: TextStyle(
                fontSize: 16,
                color: isGuest ? Colors.blue : Colors.redAccent,
              ),
            ),
            onTap: () {
              Navigator.pop(context); 

              if (isGuest) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } else {
                context.read<UserProvider>().logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
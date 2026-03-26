import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart';
import 'package:jpn_learning_app/screens/friends/addfriends_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/scenario/system_settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userAvatar = userProvider.avatar;
    final userEmail = userProvider.email ?? 'guest@example.com';
    final userName = userEmail.split('@')[0];

    // 這裡判斷是否為訪客
    final isGuest = userProvider.userId == null;

    // 產生自己的專屬預設頭像網址
    final List<String> colors = [
      'E57373',
      'F06292',
      'BA68C8',
      '9575CD',
      '7986CB',
      '64B5F6',
      '4DD0E1',
      '4DB6AC',
      '81C784',
      'AED581',
      'FFB74D',
      'FF8A65',
    ];

    int hash = 0;
    for (int i = 0; i < userName.length; i++) {
      hash = (hash * 31 + userName.codeUnitAt(i)) & 0x7FFFFFFF;
    }

    final String bgColor = colors[hash % colors.length];

    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=$bgColor&color=fff';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 換成帶有白框與專屬頭像的版本
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 74, 124, 89),
            ),
            accountName: Text(
              isGuest ? '訪客' : userName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(isGuest ? '登入解鎖更多功能！' : userEmail),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                    ? MemoryImage(base64Decode(userAvatar))
                    : NetworkImage(defaultAvatarUrl) as ImageProvider,
              ),
            ),
          ),

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
                MaterialPageRoute(
                  builder: (_) => const ResultGalleryV2Screen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('我的好友', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.person_add_outlined),
            title: const Text('新增好友', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
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

          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('系統設定', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SystemSettingsScreen(),
                  ),
                );
              });
            },
          ),

          // --- 修改後的 註冊/登入 或 登出 按鈕 ---
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
              Navigator.pop(context); // 先收起側邊欄

              if (isGuest) {
                // 訪客點擊：直接跳轉到登入畫面
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } else {
                // 會員點擊：登出再跳轉到登入畫面
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/profile/edit_profile_screen.dart';
import 'package:jpn_learning_app/screens/profile/system_settings_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isGuest = !userProvider.isLoggedIn;
    final userName = isGuest ? '訪客' : (userProvider.username ?? '使用者');
    final email = isGuest ? '登入後同步資料' : (userProvider.email ?? '尚未設定 Email');
    final jPts = userProvider.jPts;
    final avatarUrl = userProvider.avatar;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      extendBody: true, // 🌟 配合懸浮導航欄
      appBar: AppBar(
        title: const Text('個人檔案', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120), // 避免被懸浮導航欄遮擋
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 1. 使用者資訊區
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: AppColors.primaryLighter,
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
                            ? NetworkImage(avatarUrl) : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty) 
                            ? const Icon(Icons.person, size: 60, color: AppColors.primary) : null,
                      ),
                      if (!isGuest)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(email, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            // 2. 數據卡片 (J-Pts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.monetization_on_outlined, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('剩餘 J-Pts', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                          Text('$jPts Pts', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyPointsScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('儲值', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            // 3. 功能選單
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildMenuTile(Icons.settings_outlined, '系統設定', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen()));
                  }),
                  _buildMenuTile(Icons.help_outline_rounded, '幫助與回饋', () {}),
                  _buildMenuTile(Icons.info_outline_rounded, '關於我們', () {}),
                  const SizedBox(height: 20),
                  _buildMenuTile(
                    isGuest ? Icons.login_rounded : Icons.logout_rounded, 
                    isGuest ? '登入帳號' : '登出帳號', 
                    () {
                      if (!isGuest) userProvider.logout();
                      Navigator.pushAndRemoveUntil(
                        context, 
                        MaterialPageRoute(builder: (_) => const LoginScreen()), 
                        (route) => false
                      );
                    },
                    isDestructive: !isGuest,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // 🌟 修正後的導航列邏輯
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4, // 個人檔案在最右邊
        onTap: (i) {
          if (i == 0) {
            // 點擊最左邊：回到主頁 (Index 0)
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const HomeScreen()), 
              (route) => false
            );
          } else if (i == 1) {
            // 點擊相機 (Index 1)
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          } else if (i == 2) {
            // 點擊搜尋 (Index 2)
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManualSearchScreen()));
          } else if (i == 3) {
            // 點擊紀錄 (Index 3)
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()));
          } else if (i == 4) {
            // 已經在個人檔案頁面，不需跳轉
          }
        },
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDestructive ? Colors.redAccent : const Color(0xFF2C3E50)),
        title: Text(title, style: TextStyle(
          color: isDestructive ? Colors.redAccent : const Color(0xFF2C3E50),
          fontWeight: FontWeight.w800,
        )),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
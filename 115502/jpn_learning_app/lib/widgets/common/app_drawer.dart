import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  // 🌟 扁平風設計的核心配色
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
          // 1. 頁首個人資料區
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 30),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryLighter,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
                      ? NetworkImage(avatarUrl) 
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty) 
                      ? const Icon(Icons.person, size: 30, color: AppColors.primary) 
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w900, 
                          color: _textColor
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12, 
                          color: _subTextColor, 
                          fontWeight: FontWeight.w500
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. 選單列表區
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.home_rounded, 
                  title: '主頁首頁', 
                  isSelected: true,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.workspace_premium_rounded, 
                  title: '升級至 Pro',
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_rounded, 
                  title: '設定中心',
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.help_outline_rounded, 
                  title: '幫助與回饋',
                ),
              ],
            ),
          ),

          // 🌟 核心：使用 Spacer 將登出按鈕推至底部
          const Spacer(),

          // 3. 🌟 Commit 4: 底部登出按鈕
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            child: _buildMenuItem(
              context,
              icon: Icons.logout_rounded, 
              title: '登出帳號',
              isLogout: true,
              onTap: () {
                // 這裡執行登出邏輯並跳轉回登入畫面
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginScreen())
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 更新後的選單項目元件：支援登出樣式與點擊回呼
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon, 
    required String title, 
    bool isSelected = false,
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    // 根據是否為登出按鈕來決定顏色：登出為紅色，選中為原色，其餘為深灰
    Color itemColor = isLogout 
        ? Colors.redAccent 
        : (isSelected ? AppColors.primary : _textColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.primary.withOpacity(0.1) 
            : (isLogout ? Colors.redAccent.withOpacity(0.05) : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          icon, 
          color: itemColor, 
          size: 24
        ),
        title: Text(
          title,
          style: TextStyle(
            color: itemColor,
            fontWeight: isSelected || isLogout ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)
        ),
        onTap: onTap ?? () {
          // 預設為收起選單
          Navigator.pop(context);
        },
      ),
    );
  }
}
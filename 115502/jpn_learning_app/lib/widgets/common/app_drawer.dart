import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';

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
          // 1. 頁首個人資料區 (延續 Commit 2)
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

          // 2. 🌟 Commit 3: 扁平化藥丸選單列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.home_rounded, 
                  title: '主頁首頁', 
                  isSelected: true
                ),
                _buildMenuItem(
                  icon: Icons.workspace_premium_rounded, 
                  title: '升級至 Pro'
                ),
                _buildMenuItem(
                  icon: Icons.settings_rounded, 
                  title: '設定中心'
                ),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded, 
                  title: '幫助與回饋'
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  // 🌟 Commit 3: 選單項目元件定義
  Widget _buildMenuItem({
    required IconData icon, 
    required String title, 
    bool isSelected = false
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // 如果被選中，背景顯示淡綠色
        color: isSelected 
            ? AppColors.primary.withOpacity(0.1) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16), // 🌟 大圓角藥丸感
      ),
      child: ListTile(
        leading: Icon(
          icon, 
          color: isSelected ? AppColors.primary : _textColor, 
          size: 24
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : _textColor,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        // 設定點擊區域的圓角，讓水波紋效果也符合藥丸形狀
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)
        ),
        onTap: () {
          // 選單點擊邏輯
        },
      ),
    );
  }
}
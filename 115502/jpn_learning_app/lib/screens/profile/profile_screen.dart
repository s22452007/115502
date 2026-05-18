import 'dart:convert';
// Flutter 內建與第三方套件
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
import 'package:provider/provider.dart';

// 專案內的設定與 Provider
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// UI 元件與其他畫面
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/common/app_drawer.dart';

import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'photo_folder_v2_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'badge_library_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  // 🌟 統一全域現代扁平化配色 (與主頁完全一致)
  final Color _flatCanvasColor = const Color(0xFFF4F7F5); 
  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ==========================================
  // UI 轉換邏輯：等級精準對應程度稱號與進度
  // ==========================================
  
  String _getLevelTitle(String level) {
    switch (level.toUpperCase().trim()) {
      case 'N5': return '新手上路';
      case 'N4': return '生活達人';
      case 'N3': return '交流無礙';
      case 'N2': return '商務菁英';
      case 'N1': return '日語大師';
      default: return '尚未認證';
    }
  }

  double _getProgressValue(String level) {
    switch (level.toUpperCase().trim()) {
      case 'N5': return 0.20;
      case 'N4': return 0.40;
      case 'N3': return 0.60;
      case 'N2': return 0.80;
      case 'N1': return 1.00;
      default: return 0.0;
    }
  }

  // ==========================================
  // 核心邏輯函式區塊
  // ==========================================

  Future<void> _fetchData() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await ApiClient.fetchProfileData(userId);
      if (!mounted) return;

      if (result.containsKey('avatar') && result['avatar'] != null) {
        userProvider.setAvatar(result['avatar'].toString());
      }
      if (result.containsKey('username') && result['username'] != null) {
        userProvider.setUsername(result['username'].toString());
      }
      if (result.containsKey('badge_progress') && result['badge_progress'] != null) {
        userProvider.setBadgeProgress(result['badge_progress']);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('個人檔案抓取發生未知異常: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      _handleGuestClick('修改大頭貼');
      return;
    }

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('圖片上傳中...')));

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final result = await ApiClient.uploadAvatar(userId, base64String);

      if (!context.mounted) return;
      if (result.containsKey('avatar')) {
        context.read<UserProvider>().setAvatar(result['avatar']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('大頭貼更新成功！')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? '上傳失敗')));
      }
    }
  }

  Future<void> _editNickname() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      _handleGuestClick('管理個人檔案');
      return;
    }
    
    final controller = TextEditingController(text: context.read<UserProvider>().username ?? '');
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('修改暱稱', style: TextStyle(color: _textColor, fontWeight: FontWeight.w900)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '中文或英文，2～20 字',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: _flatCanvasColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700))),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = '請輸入暱稱');
                  return;
                }
                final check = await ApiClient.checkUsername(name, userId: userId);
                if (check['error'] != null) {
                  setDialogState(() => errorText = check['error']);
                  return;
                }
                if (check['available'] == false) {
                  setDialogState(() => errorText = '此暱稱已被使用');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, name);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('確認', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;
    final res = await ApiClient.updateUsername(userId, result);
    if (!mounted) return;
    if (res['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
      return;
    }
    context.read<UserProvider>().setUsername(result);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暱稱已更新')));
  }

  void _handleGuestClick(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('訪客無法使用「$featureName」功能，請先登入喔！')));
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isGuest = userProvider.userId == null;

    final email = isGuest ? '登入後同步資料' : (userProvider.email ?? '—');
    final userName = isGuest ? 'Guest' : (userProvider.username ?? email.split('@')[0]);
    final rawLevel = userProvider.japaneseLevel.isNotEmpty ? userProvider.japaneseLevel : '尚未設定';
    
    final levelTitle = _getLevelTitle(rawLevel);
    final progressValue = _getProgressValue(rawLevel);
    
    final jPts = userProvider.jPts;
    final friendId = userProvider.friendId ?? '—';
    final avatarUrl = userProvider.avatar;

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      extendBody: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.primary, size: 30),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  // 大頭照與進度條白底卡片
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 55, left: 24, right: 24),
                        padding: const EdgeInsets.fromLTRB(24, 65, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(userName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _textColor)),
                            const SizedBox(height: 6),
                            Text(email, style: TextStyle(color: _subTextColor, fontWeight: FontWeight.w600, fontSize: 14)),
                            
                            const SizedBox(height: 14),
                            
                            // 主色調稱號徽章
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12), 
                                border: Border.all(color: AppColors.primary, width: 1.5), 
                                borderRadius: BorderRadius.circular(20), 
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, color: AppColors.primary, size: 18), 
                                  const SizedBox(width: 6),
                                  Text(
                                    levelTitle, 
                                    style: const TextStyle(
                                      color: AppColors.primary, 
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 14, 
                                      letterSpacing: 1.0
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 進度條區塊
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progressValue,
                                      backgroundColor: const Color(0xFFEBEBEB),
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('${(progressValue * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15)),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 管理個人檔案按鈕
                            SizedBox(
                              width: 180,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _editNickname,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('管理個人檔案', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      // 懸浮置中大頭照
                      Positioned(
                        top: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(4), 
                            decoration: BoxDecoration(color: _flatCanvasColor, shape: BoxShape.circle),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.primaryLighter,
                              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, size: 50, color: AppColors.primary) : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 下方細項選單清單
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildListItem(
                          icon: Icons.monetization_on_rounded, 
                          title: 'J-Points', 
                          trailingText: '$jPts',
                          iconColor: AppColors.primary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreDashboardScreen(initialIndex: 1)))
                        ),
                        _buildListItem(
                          icon: Icons.folder_special_rounded, 
                          title: '我的收藏', 
                          onTap: () => isGuest ? _handleGuestClick('我的收藏') : Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoFolderV2Screen()))
                        ),
                        _buildListItem(
                          icon: Icons.people_alt_rounded, 
                          title: '好友綁定', 
                          trailingText: friendId,
                          onTap: () {} 
                        ),
                        
                        _buildListItem(
                          icon: Icons.military_tech_rounded, 
                          title: '成就徽章', 
                          iconColor: AppColors.primary,
                          onTap: () {
                            if (isGuest) {
                              _handleGuestClick('成就徽章');
                            } else {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => const BadgeLibraryScreen())
                              );
                            }
                          }
                        ),
                        
                        const SizedBox(height: 8),
                        _buildFlatInfoTile(label: '稱號認證', value: levelTitle), 
                        const SizedBox(height: 8),

                        _buildListItem(
                          icon: isGuest ? Icons.login_rounded : Icons.logout_rounded, 
                          title: isGuest ? '登入帳號' : '登出帳號', 
                          iconColor: isGuest ? AppColors.primary : Colors.redAccent,
                          textColor: isGuest ? _textColor : Colors.redAccent,
                          onTap: () {
                            if (!isGuest) context.read<UserProvider>().logout();
                            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                          }
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4,
        onTap: (i) {
          if (i == 0) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
          else if (i == 1) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          else if (i == 2) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManualSearchScreen()));
          else if (i == 3) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()));
        },
      ),
    );
  }

  // 仿照參考圖片的乾淨選單樣式
  Widget _buildListItem({
    required IconData icon, 
    required String title, 
    String? trailingText, 
    Color? iconColor, 
    Color? textColor,
    required VoidCallback onTap
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: iconColor ?? _subTextColor, size: 26),
        title: Text(title, style: TextStyle(color: textColor ?? _textColor, fontWeight: FontWeight.w800, fontSize: 16)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) 
              Text(trailingText, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // 扁平化極簡資料小卡片
  Widget _buildFlatInfoTile({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _subTextColor, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(value, style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
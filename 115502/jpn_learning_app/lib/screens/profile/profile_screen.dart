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
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'photo_folder_v2_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart';
import 'badge_library_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  
  // 🌟 新增編輯模式的狀態變數
  bool _isEditing = false;
  bool _isSaving = false;
  final TextEditingController _nameController = TextEditingController();

  // 統一全域現代扁平化配色
  final Color _flatCanvasColor = const Color(0xFFF4F7F5); 
  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose(); // 🌟 記得釋放資源
    super.dispose();
  }

  // ==========================================
  // UI 轉換邏輯
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
      if (result.containsKey('is_premium')) {
        userProvider.setIsPremium(result['is_premium'] == true);
      }
      if (result.containsKey('j_pts') && result['j_pts'] != null) {
        userProvider.setJPts((result['j_pts'] as num).toInt());
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

  // 🌟 全新實作：確認並儲存編輯狀態
  Future<void> _saveProfile() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暱稱不能為空！')));
      return;
    }

    // 檢查是否沒有變更，直接退出編輯模式即可
    final currentName = context.read<UserProvider>().username ?? '';
    if (newName == currentName) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    // 呼叫 API 檢查名稱是否重複
    final check = await ApiClient.checkUsername(newName, userId: userId);
    if (check['error'] != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(check['error'])));
      setState(() => _isSaving = false);
      return;
    }
    if (check['available'] == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('此暱稱已被使用')));
      setState(() => _isSaving = false);
      return;
    }

    // 呼叫 API 更新名稱
    final res = await ApiClient.updateUsername(userId, newName);
    if (!mounted) return;
    
    if (res['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
      setState(() => _isSaving = false);
      return;
    }

    context.read<UserProvider>().setUsername(newName);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暱稱已更新')));
    
    // 成功後退出編輯模式並關閉載入
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
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
                            // 🌟 判斷是否為編輯模式：顯示文字 或 顯示編輯輸入框
                            if (_isEditing)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _nameController,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textColor),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    filled: true,
                                    fillColor: _flatCanvasColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                  ),
                                ),
                              )
                            else
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
                            
                            // 🌟 編輯/確認按鈕
                            SizedBox(
                              width: 180,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isSaving 
                                  ? null 
                                  : () {
                                      if (isGuest) {
                                        _handleGuestClick('管理個人檔案');
                                      } else {
                                        if (_isEditing) {
                                          _saveProfile();
                                        } else {
                                          setState(() {
                                            _nameController.text = userName; // 進入編輯模式時，填入當前名稱
                                            _isEditing = true;
                                          });
                                        }
                                      }
                                    },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                                ),
                                child: _isSaving
                                  ? const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                    )
                                  : Text(
                                      _isEditing ? '確認' : '管理個人檔案', 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)
                                    ),
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      // 🌟 懸浮置中大頭照 (加入編輯圖示)
                      Positioned(
                        top: 0,
                        child: Stack(
                          children: [
                            GestureDetector(
                              // 只有在編輯模式時才可以點擊更換頭像
                              onTap: _isEditing ? _pickAndUploadImage : null,
                              child: Container(
                                padding: const EdgeInsets.all(4), 
                                decoration: BoxDecoration(color: _flatCanvasColor, shape: BoxShape.circle),
                                child: UserAvatar(
                                  avatarBase64: avatarUrl,
                                  friendId: userProvider.friendId,
                                  originalName: userName,
                                  radius: 50,
                                  isPremium: userProvider.isPremium,
                                ),
                              ),
                            ),
                            // 如果是編輯模式，顯示小小的筆形 ICON
                            if (_isEditing)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _pickAndUploadImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                          ],
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
                          iconColor: AppColors.primary,
                          onTap: () => isGuest ? _handleGuestClick('我的收藏') : Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoFolderV2Screen()))
                        ),
                        _buildListItem(
                          icon: Icons.people_alt_rounded,
                          title: '好友綁定',
                          iconColor: AppColors.primary,
                          trailingText: friendId,
                          onTap: () => isGuest
                              ? _handleGuestClick('好友綁定')
                              : Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsListScreen()))
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
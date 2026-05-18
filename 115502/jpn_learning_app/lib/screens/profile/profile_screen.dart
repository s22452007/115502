import 'dart:convert';
// Flutter 內建與第三方套件
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// 專案內的設定與 Provider
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/helpers.dart'; 

// UI 元件與其他畫面
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/common/app_drawer.dart';
import 'package:jpn_learning_app/widgets/profile/profile_radar_section.dart';
import 'package:jpn_learning_app/widgets/profile/profile_achievements_section.dart';

import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'photo_folder_v2_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  List<double> _radarValues = [0.2, 0.2, 0.2, 0.2, 0.2];

  // 統一全域現代扁平化配色
  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ==========================================
  // 邏輯函式區塊 (100% 保留原生功能與高容錯)
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

      // 同步大頭貼、名稱、徽章
      if (result.containsKey('avatar') && result['avatar'] != null) {
        userProvider.setAvatar(result['avatar'].toString());
      }
      if (result.containsKey('username') && result['username'] != null) {
        userProvider.setUsername(result['username'].toString());
      }
      if (result.containsKey('badge_progress') && result['badge_progress'] != null) {
        userProvider.setBadgeProgress(result['badge_progress']);
      }

      // 檢查五向雷達圖能力值
      if (result.containsKey('ability') && result['ability'] != null) {
        setState(() {
          _radarValues = [
            (result['ability']['listening'] ?? 0.2).toDouble(),
            (result['ability']['speaking'] ?? 0.2).toDouble(),
            (result['ability']['reading'] ?? 0.2).toDouble(),
            (result['ability']['writing'] ?? 0.2).toDouble(),
            (result['ability']['culture'] ?? 0.2).toDouble(),
          ];
          _isLoading = false;
        });
      } else {
        setState(() {
          _radarValues = [0.2, 0.2, 0.2, 0.2, 0.2];
          _isLoading = false;
        });
      }
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
    final controller = TextEditingController(
      text: context.read<UserProvider>().username ?? '',
    );
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('修改暱稱', style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '中文或英文，2～20 字',
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
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
              child: const Text('確認', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || userId == null) return;
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
    final japaneseLevel = userProvider.japaneseLevel.isNotEmpty ? userProvider.japaneseLevel : '尚未設定';
    final friendId = userProvider.friendId ?? '—';
    final avatarUrl = userProvider.avatar;

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      extendBody: true, // 🌟 配合懸浮導航欄
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _flatCanvasColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.primary, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text('個人檔案', style: TextStyle(color: _textColor, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120), // 底部留白避免被懸浮欄遮擋
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // 🌟 1. 大頭照置中區塊
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty) ? Icon(Icons.person, size: 60, color: AppColors.primary) : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🌟 2. 大頭照正下方的日檢等級進度條
                  Center(
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(japaneseLevel, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                              Text('學習進度', style: TextStyle(color: _subTextColor, fontWeight: FontWeight.w700, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: const LinearProgressIndicator(
                              value: 0.65, // 這裡可以放入目前的關卡進度比例，先以好看的 0.65 預設
                              backgroundColor: Color(0xFFEBEBEB),
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // 🌟 3. 基本資訊區塊 (扁平大圓角卡片)
                  Text('基本資料', style: TextStyle(color: _subTextColor, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _buildFlatInfoTile(label: '暱稱', value: userName, isEditable: true, onTap: _editNickname),
                  _buildFlatInfoTile(label: 'Email', value: email),
                  _buildFlatInfoTile(label: '日文等級', value: japaneseLevel),
                  _buildFlatInfoTile(label: '好友 ID', value: friendId),
                  
                  const SizedBox(height: 25),

                  // 🌟 4. 能力分析雷達圖區塊
                  Text('能力分析', style: TextStyle(color: _subTextColor, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  ProfileRadarSection(isGuest: isGuest, radarValues: _radarValues),
                  
                  const SizedBox(height: 25),

                  // 🌟 5. 成就徽章區塊
                  ProfileAchievementsSection(isGuest: isGuest, onGuestClick: _handleGuestClick),
                  const SizedBox(height: 25),

                  // 🌟 6. 收藏夾區塊
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('收藏夾', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textColor)),
                        TextButton(
                          onPressed: () => isGuest
                              ? _handleGuestClick('收藏夾')
                              : Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoFolderV2Screen())),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('查看全部', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      // 底部懸浮橢圓導航欄
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
          } else if (i == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          } else if (i == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManualSearchScreen()));
          } else if (i == 3) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()));
          } else if (i == 4) {
            // 已在個人頁
          }
        },
      ),
    );
  }

  // 扁平化極簡資料卡片組件
  Widget _buildFlatInfoTile({required String label, required String value, bool isEditable = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: isEditable ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: _subTextColor, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isEditable) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
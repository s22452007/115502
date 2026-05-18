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
import 'package:jpn_learning_app/widgets/profile/profile_header.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ==========================================
  // 邏輯函式區塊 (已補上高容錯同步機制)
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

      // 🌟 核心防呆：不論 ability 是否存在，第一時間一定要把大頭貼、名稱、徽章同步進來
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
        // 🌟 防呆：若無能力值資料則給予基礎 0.2 預設值，不彈出失敗錯誤，讓使用者能正常看見大頭貼與其他選單
        setState(() {
          _radarValues = [0.2, 0.2, 0.2, 0.2, 0.2];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('個人檔案抓取發生未知異常: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步資料時發生錯誤: $e')),
        );
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片上傳中...')));

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final result = await ApiClient.uploadAvatar(userId, base64String);

      if (!context.mounted) return;
      if (result.containsKey('avatar')) {
        context.read<UserProvider>().setAvatar(result['avatar']);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('大頭貼更新成功！')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['error'] ?? '上傳失敗')));
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
          title: const Text('修改暱稱'),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = '請輸入暱稱');
                  return;
                }
                final check = await ApiClient.checkUsername(
                  name,
                  userId: userId,
                );
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
              child: const Text(
                '確認',
                style: TextStyle(color: Color.fromARGB(255, 74, 124, 89)),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || userId == null) return;
    final res = await ApiClient.updateUsername(userId, result);
    if (!mounted) return;
    if (res['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res['error'])));
      return;
    }
    context.read<UserProvider>().setUsername(result);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('暱稱已更新')));
  }

  void _handleGuestClick(String featureName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('訪客無法使用「$featureName」功能，請先登入喔！')));
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isGuest = userProvider.userId == null;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 74, 124, 89),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileHeader(
                    isGuest: isGuest,
                    userName:
                        userProvider.username ??
                        userProvider.email?.split('@')[0] ??
                        'Guest',
                    friendId: userProvider.friendId,
                    userAvatar: userProvider.avatar,
                    
                    rawLevel: userProvider.japaneseLevel, 
                    
                    onAvatarTap: _pickAndUploadImage,
                    onNameTap: _editNickname,
                    ),
                  const SizedBox(height: 32),
                  ProfileRadarSection(
                    isGuest: isGuest,
                    radarValues: _radarValues,
                  ),
                  const SizedBox(height: 24),
                  ProfileAchievementsSection(
                    isGuest: isGuest,
                    onGuestClick: _handleGuestClick,
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '收藏夾',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        TextButton(
                          onPressed: () => isGuest
                              ? _handleGuestClick('收藏夾')
                              : Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoFolderV2Screen(),
                                  ),
                                ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '查看全部',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 74, 124, 89),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Color.fromARGB(255, 74, 124, 89),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          } else if (i == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
            );
          } else if (i == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()),
            );
          } else if (i == 4) {
            // 已在個人頁
          }
        },
      ),
    );
  }
}
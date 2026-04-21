import 'dart:convert';
// Flutter 內建與第三方套件
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// 專案內的設定與 Provider
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// UI 元件與其他畫面
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/common/app_drawer.dart';
import 'package:jpn_learning_app/widgets/profile/profile_header.dart';
import 'package:jpn_learning_app/widgets/profile/profile_radar_section.dart';
import 'package:jpn_learning_app/widgets/profile/profile_achievements_section.dart';

import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'photo_folder_v2_screen.dart';

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
  // 邏輯函式區塊
  // ==========================================

  // 將資料庫的 N 等級轉換為好聽的稱號
  String _getDisplayLevel(String? dbLevel) {
    if (dbLevel == null || dbLevel.isEmpty) return '尚未設定等級';
    switch (dbLevel) {
      case 'N1':
        return '日語大師';
      case 'N2':
        return '商務菁英';
      case 'N3':
        return '交流無礙';
      case 'N4':
        return '生活達人';
      case 'N5':
      default:
        return '日語新手';
    }
  }

  Future<void> _fetchData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await ApiClient.fetchProfileData(userId);
    if (!mounted) return;

    if (result.containsKey('ability')) {
      setState(() {
        _radarValues = [
          result['ability']['listening'].toDouble(),
          result['ability']['speaking'].toDouble(),
          result['ability']['reading'].toDouble(),
          result['ability']['writing'].toDouble(),
          result['ability']['culture'].toDouble(),
        ];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('抓取資料失敗')));
    }

    if (result.containsKey('badge_progress')) {
      context.read<UserProvider>().setBadgeProgress(result['badge_progress']);
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
                    userAvatar: userProvider.avatar,
                    rawLevel: userProvider.japaneseLevel ?? '',
                    onAvatarTap: _pickAndUploadImage,
                    onNameTap: _editNickname,
                    getDisplayLevel: _getDisplayLevel,
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

                  // 收藏夾區塊因為很單純，可以直接寫在這裡，或是你之後也可以把它拆出去
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
    );
  }
}

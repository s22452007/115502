import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/route_observer.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/widgets/common/app_drawer.dart';
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/home/daily_goal_card.dart';
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';
import 'package:jpn_learning_app/widgets/dialogs/vocab_bottom_sheet.dart';
import 'package:jpn_learning_app/widgets/common/premium_locked_overlay.dart';
import 'package:jpn_learning_app/widgets/home/recent_scenes_list.dart';
import 'package:jpn_learning_app/widgets/common/status_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  int _currentIndex = 2; 
  int? _lastUserId;
  List<dynamic> _recentScenes = [];
  bool _isLoadingScenes = true;

  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);
  final Color _flatCanvasColor = const Color(0xFFF4F7F5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _syncHomeData(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    final currentUserId = Provider.of<UserProvider>(context).userId;
    if (_lastUserId != currentUserId) {
      _lastUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) { _syncHomeData(); });
    }
  }

  @override
  void dispose() { routeObserver.unsubscribe(this); super.dispose(); }

  @override
  void didPopNext() { _syncHomeData(); }

  Future<void> _syncHomeData() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() { _recentScenes = []; _isLoadingScenes = false; });
      return;
    }
    if (!mounted) return;
    setState(() { _isLoadingScenes = true; });
    await _checkPendingFriendRequests();
    await _fetchRecentScenes();
    await _fetchAndCheckBadgeProgress();
  }

  Future<void> _fetchAndCheckBadgeProgress() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) return;
    try {
      final result = await ApiClient.fetchProfileData(userId);
      if (!mounted) return;
      if (result.containsKey('badge_progress')) {
        final newProgress = result['badge_progress'] as Map<String, dynamic>;
        Map<String, dynamic> notifiedLevels = {};
        final rawNotified = result['notified_levels'];
        if (rawNotified is Map) {
          notifiedLevels = Map<String, dynamic>.from(rawNotified);
        } else if (rawNotified is String && rawNotified.isNotEmpty) {
          try { notifiedLevels = json.decode(rawNotified); } catch (e) {}
        }
        for (String id in BadgeUtils.milestones.keys) {
          int currentVal = 0, currentLvl = 0;
          if (id == 'level_01') {
            final String? levelStr = result['japanese_level'];
            currentLvl = BadgeUtils.japaneseLevelToNumber(levelStr);
            if (levelStr != null) userProvider.setJapaneseLevel(levelStr);
          } else {
            currentVal = (newProgress[id] is int) ? newProgress[id] : (newProgress[id] as num?)?.toInt() ?? 0;
            currentLvl = BadgeUtils.calculateLevel(currentVal, id);
          }
          int notifiedLvl = (notifiedLevels[id] as num?)?.toInt() ?? 0;
          if (currentLvl > notifiedLvl) {
            await LevelUpDialog.show(context, badgeId: id, level: currentLvl);
            await ApiClient.markBadgeSeen(userId, id, currentLvl);
          }
        }
        userProvider.setBadgeProgress(newProgress);
      }
    } catch (e) { debugPrint('❌ [BadgeCheck] 發生錯誤: $e'); }
  }

  Future<void> _fetchRecentScenes() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() { _recentScenes = []; _isLoadingScenes = false; });
      return;
    }
    try {
      final scenes = await ApiClient.getUnlockedScenes(userId, limit: 3);
      if (!mounted) return;
      setState(() { _recentScenes = scenes; _isLoadingScenes = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingScenes = false);
    }
  }

  Future<void> _checkPendingFriendRequests() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) return;
    try {
      final result = await ApiClient.getPendingRequests(userId);
      if (result.containsKey('pending_requests') && result['pending_requests'] is List) {
        final List requests = result['pending_requests'];
        userProvider.setPendingFriendRequests(requests.length);
      }
    } catch (e) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '早安';
    if (hour >= 12 && hour < 18) return '午安';
    return '晚安';
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isGuest = userProvider.userId == null;
    final userEmail = userProvider.email ?? '';
    final userName = isGuest ? '訪客' : ((userProvider.username?.trim().isNotEmpty ?? false) ? userProvider.username!.trim() : (userEmail.isNotEmpty ? userEmail.split('@')[0] : '使用者'));
    final avatarUrl = userProvider.avatar;

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), color: _textColor, onPressed: () {}),
          const SizedBox(width: 12),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 頁首個人資料區
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 110, 24, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.primaryLighter,
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty) ? Icon(Icons.person, size: 40, color: AppColors.primary) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(), style: TextStyle(fontSize: 14, color: _subTextColor, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('$userName!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _textColor, height: 1.2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🌟 Commit 3: 加入打卡日曆卡片殼子
            _buildCheckInCalendarCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())).then((_) => _syncHomeData());
          if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualSearchScreen())).then((_) => _syncHomeData());
          if (i == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())).then((_) => _syncHomeData());
          if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen())).then((_) => _syncHomeData());
          if (i == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _syncHomeData());
        },
      ),
    );
  }

  // 🌟 Commit 3: 打卡日曆元件 (外殼)
  Widget _buildCheckInCalendarCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            child: Text(
              '本週打卡', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textColor),
            ),
          ),
          // 內部點點留待 Commit 4
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
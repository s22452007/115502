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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncHomeData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    final currentUserId = Provider.of<UserProvider>(context).userId;
    if (_lastUserId != currentUserId) {
      _lastUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncHomeData();
      });
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _syncHomeData();
  }

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
    final streakDays = userProvider.streakDays;
    final jPts = userProvider.jPts;

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        title: Icon(Icons.camera_alt_rounded, color: _textColor, size: 28),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}，\n$userName!', 
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _textColor, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              '今天也是學習日語的好日子',
              style: TextStyle(fontSize: 15, color: _subTextColor, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                StatusChip(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  text: isGuest ? '登入挑戰' : '連續$streakDays天',
                  borderColor: Colors.transparent, 
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => isGuest ? const LoginScreen() : const BuyPointsScreen())),
                  child: StatusChip(
                    icon: Icons.monetization_on,
                    iconColor: Colors.blue,
                    text: isGuest ? '0 J-Pts' : '$jPts J-Pts',
                    borderColor: Colors.transparent,
                  ),
                ),
              ],
            ),
            
            // 🌟 Commit 3: 標題風格升級
            const SizedBox(height: 40),
            Text(
              '今日學習目標',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _textColor),
            ),
            const SizedBox(height: 16),
            isGuest
                ? PremiumLockedOverlay(
                    message: '登入啟用今日目標',
                    child: DailyGoalCard(onReturnFromCamera: _fetchAndCheckBadgeProgress),
                  )
                : DailyGoalCard(onReturnFromCamera: _fetchAndCheckBadgeProgress),
            
            const SizedBox(height: 40),
            
            // 🌟 Commit 3: 連結樣式優化
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近解鎖場景', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _textColor)
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen())),
                  child: const Text(
                    '我的單字探險 >', 
                    style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            RecentScenesList(
              recentScenes: _recentScenes,
              isLoadingScenes: _isLoadingScenes,
              onShowVocabularyBottomSheet: (scene) => VocabBottomSheet.show(context, scene, context.read<UserProvider>().userId?.toString()),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())).then((_) => _syncHomeData());
          if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualSearchScreen())).then((_) => _syncHomeData());
          if (i == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())).then((_) => _syncHomeData());
          if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen())).then((_) => _syncHomeData());
          if (i == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _syncHomeData());
        },
      ),
    );
  }
}
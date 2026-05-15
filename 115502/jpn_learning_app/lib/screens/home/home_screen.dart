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
  int? _lastUserId; 
  List<dynamic> _recentScenes = [];
  bool _isLoadingScenes = true;

  final Color _textColor = const Color(0xFF2C3E50); 
  final Color _subTextColor = const Color(0xFF8E9AAB);
  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _brandColor = const Color(0xFF006D3E);

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

    await _checkPendingFriendRequests(userId);
    await _fetchRecentScenes(userId);
    await _fetchAndCheckBadgeProgress(userId);
  }

  Future<void> _fetchAndCheckBadgeProgress(int userId) async {
    final userProvider = context.read<UserProvider>();
    try {
      final result = await ApiClient.fetchProfileData(userId);
      if (!mounted) return;
      if (result.containsKey('badge_progress')) {
        userProvider.setBadgeProgress(result['badge_progress'] as Map<String, dynamic>);
      }
      if (result.containsKey('j_pts')) {
        userProvider.setJPts((result['j_pts'] as num).toInt());
      }
      if (result.containsKey('streak_days')) {
        userProvider.setStreakDays((result['streak_days'] as num).toInt());
      }
    } catch (e) { debugPrint('資料同步錯誤: $e'); }
  }

  Future<void> _fetchRecentScenes(int userId) async {
    try {
      final scenes = await ApiClient.getUnlockedScenes(userId, limit: 3);
      if (!mounted) return;
      setState(() { _recentScenes = scenes; _isLoadingScenes = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingScenes = false);
    }
  }

  Future<void> _checkPendingFriendRequests(int userId) async {
    final userProvider = context.read<UserProvider>();
    try {
      final result = await ApiClient.getPendingRequests(userId);
      if (result.containsKey('pending_requests')) {
        userProvider.setPendingFriendRequests((result['pending_requests'] as List).length);
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
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    List<DateTime> weekDates = List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));
    List<String> weekDayNames = ['一', '二', '三', '四', '五', '六', '日'];

    final userProvider = context.watch<UserProvider>();
    final isGuest = !userProvider.isLoggedIn;
    final userName = isGuest ? '訪客' : (userProvider.username ?? '使用者');
    final jPts = userProvider.jPts;
    final streakDays = userProvider.streakDays;
    final avatarUrl = userProvider.avatar;

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        // 🌟 1. 改成實體背景色
        backgroundColor: _flatCanvasColor,
        elevation: 0,
        // 確保向上捲動時不會有陰影線條
        scrolledUnderElevation: 0, 
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 30),
            color: _textColor,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset(
          'assets/images/logo.png', 
          height: 35, 
          errorBuilder: (c,e,s) => Text("J-LENS", style: TextStyle(color: _brandColor, fontWeight: FontWeight.w900))
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 30), 
            color: _textColor, 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const SizedBox(width: 12),
        ],
      ),
      // 🌟 2. 移除 extendBodyBehindAppBar (預設為 false)
      
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 頁首歡迎區 + 連續登入天數
            Container(
              width: double.infinity,
              // 🌟 3. 調整頂部 Padding (原本是 115，縮小成 20)
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
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
                        Text(_getGreeting(), style: TextStyle(fontSize: 14, color: _subTextColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('$userName!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _textColor, letterSpacing: 0.5)),
                        
                        // 連續登入天數 Chip
                        if (!isGuest) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                                const SizedBox(width: 4),
                                Text('已連續登入 $streakDays 天', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 本週打卡日曆卡片
            _buildCheckInCalendarCard(weekDates, weekDayNames, streakDays),

            // 3. J-Pts 狀態
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  icon: Icons.monetization_on_outlined, 
                  iconColor: AppColors.primary, 
                  text: isGuest ? '登入購買 J-Pts' : '$jPts J-Pts',
                  borderColor: Colors.transparent,
                ),
              ),
            ),

            const SizedBox(height: 15),
            
            // 4. 今日學習目標
            _buildSectionHeader('今日學習目標'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isGuest
                  ? PremiumLockedOverlay(message: '登入啟用今日目標', child: DailyGoalCard(onReturnFromCamera: () => _syncHomeData()))
                  : DailyGoalCard(onReturnFromCamera: () => _syncHomeData()),
            ),

            const SizedBox(height: 35),

            // 5. 最近解鎖場景
            _buildSectionHeader('最近解鎖場景', hasGalleryLink: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: RecentScenesList(
                recentScenes: _recentScenes,
                isLoadingScenes: _isLoadingScenes,
                onShowVocabularyBottomSheet: (scene) => VocabBottomSheet.show(context, scene, userProvider.userId?.toString()),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())).then((_) => _syncHomeData());
          if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen())).then((_) => _syncHomeData());
          if (i == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        },
      ),
    );
  }

  // --- UI 組件方法 ---

  Widget _buildCheckInCalendarCard(List<DateTime> weekDates, List<String> weekDayNames, int streakDays) {
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本週打卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textColor)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = weekDates[index];
              final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
              bool isCompleted = (now.difference(date).inDays >= 0 && streakDays > now.difference(date).inDays);
              return Column(
                children: [
                  Text(weekDayNames[index], style: TextStyle(fontSize: 12, color: _subTextColor, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: isToday ? AppColors.primary : (isCompleted ? AppColors.primary.withOpacity(0.6) : Colors.grey.withOpacity(0.1)), shape: BoxShape.circle),
                    child: Center(child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 20) : Text(date.day.toString(), style: TextStyle(color: isToday ? Colors.white : _textColor, fontWeight: FontWeight.w900))),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool hasGalleryLink = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _textColor, letterSpacing: 0.5)),
          if (hasGalleryLink)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen())),
              child: Text('查看全部 >', style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}
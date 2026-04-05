import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 工具與 Provider
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 2. 共用元件
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';
import 'package:jpn_learning_app/widgets/daily_goal_card.dart';
import 'package:jpn_learning_app/widgets/study_group_card.dart';
import 'package:jpn_learning_app/widgets/premium_locked_overlay.dart';
import 'package:jpn_learning_app/widgets/status_chip.dart';
import 'package:jpn_learning_app/widgets/recent_scenes_list.dart';

// 3. 畫面 Screens
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';

// 4. Dialogs
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';
import 'package:jpn_learning_app/widgets/dialogs/vocab_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2; // 預設停留在首頁

  // 顏色定義
  final Color _goalGreen = const Color(0xFF6AA86B);
  final Color _textColor = const Color(0xFF333333);
  final Color _subTextColor = const Color(0xFF888888);

  // ==========================================
  // 1. 狀態變數與生命週期 (包含徽章設定)
  // ==========================================
  List<dynamic> _recentScenes = [];
  bool _isLoadingScenes = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingFriendRequests();
      _fetchRecentScenes(); 
      _fetchAndCheckBadgeProgress(); // 🌟 首頁載入時檢查是否升級
    });
  }

  // ==========================================
  // 2. API 資料抓取與進度檢查
  // ==========================================
  
  // 向後端抓取 Profile，檢查有沒有升級！
  Future<void> _fetchAndCheckBadgeProgress() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) return; // 訪客不檢查

    // 先記住舊的進度
    final oldProgress = Map<String, int>.from(userProvider.badgeProgress);

    try {
      final result = await ApiClient.fetchProfileData(userId);
      
      if (!mounted) return;

      if (result.containsKey('badge_progress')) {
        final newProgress = result['badge_progress'] as Map<String, dynamic>;

        // 只有舊進度存在時才檢查升級 (避免使用者第一次登入時瘋狂跳彈窗)
        if (oldProgress.isNotEmpty) {
          for (String id in BadgeUtils.badgeMilestones.keys) {
            int oldVal = oldProgress[id] ?? 0;
            int newVal = newProgress[id] is int ? newProgress[id] : (newProgress[id] as num?)?.toInt() ?? 0;

            int oldLevel = BadgeUtils.calculateLevel(oldVal, BadgeUtils.badgeMilestones[id]!);
            int newLevel = BadgeUtils.calculateLevel(newVal, BadgeUtils.badgeMilestones[id]!);

            // 如果等級變高了，就叫出慶祝彈窗！
            if (newLevel > oldLevel) {
              if (mounted) await LevelUpDialog.show(context, id, newLevel);
            }
          }
        }
        
        // 存入最新的進度給 Provider
        userProvider.setBadgeProgress(newProgress);
      }
    } catch (e) {
      debugPrint('檢查徽章進度失敗: $e');
    }
  }

  Future<void> _fetchRecentScenes() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    
    if (userId == null) {
      setState(() => _isLoadingScenes = false);
      return;
    }

    try {
      final scenes = await ApiClient.getUnlockedScenes(userId, limit: 3);
      setState(() {
        _recentScenes = scenes;
        _isLoadingScenes = false;
      });
    } catch (e) {
      debugPrint('載入最近解鎖場景失敗: $e');
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
    } catch (e) {
      debugPrint('檢查好友邀請失敗: $e');
    }
  }

  // ==========================================
  // 3. 輔助函式與彈出視窗
  // ==========================================
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '早安';
    if (hour >= 12 && hour < 18) return '午安';
    return '晚安';
  }

  // ==========================================
  // 5. 主畫面排版 (Main Build)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final userEmail = context.watch<UserProvider>().email ?? 'guest@example.com';
    final userName = context.watch<UserProvider>().username ?? userEmail.split('@')[0];
    final streakDays = context.watch<UserProvider>().streakDays;
    final jPts = context.watch<UserProvider>().jPts;
    final isGuest = context.watch<UserProvider>().userId == null;

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
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_getGreeting()}，$userName!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 4),
            Text('今天也是學習日語的好日子', style: TextStyle(fontSize: 14, color: _subTextColor)),
            const SizedBox(height: 16),
            Row(
              children: [
                StatusChip(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  text: isGuest ? '登入挑戰' : '連續$streakDays天',
                  borderColor: Colors.orange.shade200,
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => isGuest ? const LoginScreen() : const BuyPointsScreen()));
                  },
                  child: StatusChip(
                    icon: Icons.monetization_on,
                    iconColor: Colors.blue,
                    text: isGuest ? '0 J-Pts' : '$jPts J-Pts',
                    borderColor: Colors.blue.shade200,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('今日學習目標', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            isGuest
                ? PremiumLockedOverlay(child: DailyGoalCard(), message: '登入啟用今日目標')
                : DailyGoalCard(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最近解鎖場景', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen())),
                  child: Text('我的單字探險 >', style: TextStyle(fontSize: 14, color: _goalGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RecentScenesList(
              recentScenes: _recentScenes,
              isLoadingScenes: _isLoadingScenes,
              onShowVocabularyBottomSheet: (scene) => VocabBottomSheet.show(context, scene, context.read<UserProvider>().userId),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: isGuest ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen())),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('學習小組動態', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
            ),
            const SizedBox(height: 12),
            isGuest
                ? PremiumLockedOverlay(child: StudyGroupCard(), message: '登入查看群組動態')
                : GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen())),
                    child: StudyGroupCard(),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualSearchScreen()));
          if (i == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen()));
          if (i == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        },
      ),
    );
  }
}
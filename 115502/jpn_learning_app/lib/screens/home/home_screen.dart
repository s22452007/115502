/// 首頁畫面
/// 負責顯示學習應用的主要介面，包含：
/// - 用戶問候與狀態資訊（學習天數、點數）
/// - 每日學習目標進度
/// - 最近解鎖的學習場景列表
/// - 學習小組動態
/// - 徽章升級檢查與慶祝對話框

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ==========================================
// 2. 常數、工具與 API (Utils & Services)
// ==========================================
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';
import 'package:jpn_learning_app/utils/constants.dart';

// ==========================================
// 3. 狀態管理 (Providers)
// ==========================================
import 'package:jpn_learning_app/providers/user_provider.dart';

// ==========================================
// 4. 畫面路由 (Screens - 切換頁面用)
// ==========================================
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';

// ==========================================
// 5. 獨立 UI 元件與彈出視窗 (Widgets & Dialogs - 組成首頁的樂高積木)
// ==========================================
import 'package:jpn_learning_app/widgets/common/app_drawer.dart';
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/home/daily_goal_card.dart';
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';
import 'package:jpn_learning_app/widgets/dialogs/vocab_bottom_sheet.dart';
import 'package:jpn_learning_app/widgets/common/premium_locked_overlay.dart';
import 'package:jpn_learning_app/widgets/home/recent_scenes_list.dart';
import 'package:jpn_learning_app/widgets/common/status_chip.dart';
import 'package:jpn_learning_app/widgets/home/study_group_card.dart';

/// 首頁畫面狀態管理類別
/// 負責管理首頁的所有狀態和業務邏輯
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2; // 預設停留在首頁
  int? _lastUserId; // 追蹤登入狀態變化用

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
      _syncHomeData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentUserId = Provider.of<UserProvider>(context).userId;

    if (_lastUserId != currentUserId) {
      _lastUserId = currentUserId;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncHomeData();
      });
    }
  }

  Future<void> _syncHomeData() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;

    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _recentScenes = [];
        _isLoadingScenes = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingScenes = true;
    });

    await _checkPendingFriendRequests();
    await _fetchRecentScenes();
    await _fetchAndCheckBadgeProgress();
  }

  // ==========================================
  // 2. API 資料抓取與進度檢查
  // ==========================================

  /// 檢查徽章進度並顯示升級慶祝對話框
  /// 這個函式負責：
  /// Step 1: 從後端獲取最新的用戶資料（包含徽章進度）
  /// Step 2: 比較舊進度與新進度，判斷是否有徽章等級提升
  /// Step 3: 如果有升級，顯示動畫慶祝對話框
  /// Step 4: 更新 UserProvider 中的徽章進度資料
  Future<void> _fetchAndCheckBadgeProgress() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    if (userId == null) return;

    try {
      final result = await ApiClient.fetchProfileData(userId);
      if (!mounted) return;

      if (result.containsKey('badge_progress')) {
        final newProgress = result['badge_progress'] as Map<String, dynamic>;

        // 防呆加強版：處理 SQLite 傳回來的可能是一般字串 "{}" 的情況
        Map<String, dynamic> notifiedLevels = {};
        final rawNotified = result['notified_levels'];

        if (rawNotified is Map) {
          notifiedLevels = Map<String, dynamic>.from(rawNotified);
        } else if (rawNotified is String && rawNotified.isNotEmpty) {
          try {
            notifiedLevels = json.decode(rawNotified);
          } catch (e) {
            debugPrint('JSON 解碼失敗: $e');
          }
        }

        // 開始比對每個徽章
        for (String id in BadgeUtils.milestones.keys) {
          int currentVal = 0;
          int currentLvl = 0;

          if (id == 'level_01') {
            final String? levelStr = result['japanese_level'];
            currentLvl = BadgeUtils.japaneseLevelToNumber(levelStr);
            if (levelStr != null) userProvider.setJapaneseLevel(levelStr);
          } else {
            currentVal = (newProgress[id] is int)
                ? newProgress[id]
                : (newProgress[id] as num?)?.toInt() ?? 0;
            currentLvl = BadgeUtils.calculateLevel(currentVal, id);
          }

          int notifiedLvl = (notifiedLevels[id] as num?)?.toInt() ?? 0;

          // 終極判斷：實際等級 > 已經看過的等級
          if (currentLvl > notifiedLvl) {
            await LevelUpDialog.show(context, badgeId: id, level: currentLvl);
            await ApiClient.markBadgeSeen(userId, id, currentLvl);
          }
        }

        userProvider.setBadgeProgress(newProgress);
      }
    } catch (e) {
      debugPrint('❌ [BadgeCheck] 發生錯誤: $e');
    }
  }

  Future<void> _fetchRecentScenes() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;

    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _recentScenes = [];
        _isLoadingScenes = false;
      });
      return;
    }

    try {
      final scenes = await ApiClient.getUnlockedScenes(userId, limit: 3);
      if (!mounted) return;

      setState(() {
        _recentScenes = scenes;
        _isLoadingScenes = false;
      });
    } catch (e) {
      debugPrint('載入最近解鎖場景失敗: $e');
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
      if (result.containsKey('pending_requests') &&
          result['pending_requests'] is List) {
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
    final userProvider = context.watch<UserProvider>();

    final isGuest = userProvider.userId == null;
    final userEmail = userProvider.email ?? '';
    final userName = isGuest
        ? '訪客'
        : ((userProvider.username?.trim().isNotEmpty ?? false)
              ? userProvider.username!.trim()
              : (userEmail.isNotEmpty ? userEmail.split('@')[0] : '使用者'));

    final streakDays = userProvider.streakDays;
    final jPts = userProvider.jPts;

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
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}，$userName!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '今天也是學習日語的好日子',
              style: TextStyle(fontSize: 14, color: _subTextColor),
            ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isGuest
                            ? const LoginScreen()
                            : const BuyPointsScreen(),
                      ),
                    );
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
            const Text(
              '今日學習目標',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            isGuest
                ? PremiumLockedOverlay(
                    message: '登入啟用今日目標',
                    child: DailyGoalCard(
                      onReturnFromCamera: _fetchAndCheckBadgeProgress,
                    ),
                  )
                : DailyGoalCard(
                    onReturnFromCamera: _fetchAndCheckBadgeProgress,
                  ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近解鎖場景',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResultGalleryV2Screen(),
                    ),
                  ),
                  child: Text(
                    '我的單字探險 >',
                    style: TextStyle(
                      fontSize: 14,
                      color: _goalGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RecentScenesList(
              recentScenes: _recentScenes,
              isLoadingScenes: _isLoadingScenes,
              onShowVocabularyBottomSheet: (scene) => VocabBottomSheet.show(
                context,
                scene,
                context.read<UserProvider>().userId?.toString(),
              ),
            ),

            // 你原本註解掉的學習小組區塊先保留不動
            // const SizedBox(height: 24),
            // GestureDetector(
            //   onTap: isGuest
            //       ? null
            //       : () => Navigator.push(
            //           context,
            //           MaterialPageRoute(
            //             builder: (_) => const StudyGroupScreen(),
            //           ),
            //         ),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: [
            //       const Text(
            //         '學習小組動態',
            //         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            //       ),
            //       Icon(Icons.chevron_right, color: Colors.grey.shade600),
            //     ],
            //   ),
            // ),
            // const SizedBox(height: 12),
            // isGuest
            //     ? PremiumLockedOverlay(
            //         child: StudyGroupCard(),
            //         message: '登入查看群組動態',
            //       )
            //     : GestureDetector(
            //         onTap: () => Navigator.push(
            //           context,
            //           MaterialPageRoute(
            //             builder: (_) => const StudyGroupScreen(),
            //           ),
            //         ),
            //         child: StudyGroupCard(),
            //       ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);

          if (i == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            ).then((_) => _syncHomeData());
          }

          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
            ).then((_) => _syncHomeData());
          }

          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ).then((_) => _syncHomeData());
          }

          if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()),
            ).then((_) => _syncHomeData());
          }

          if (i == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _syncHomeData());
          }
        },
      ),
    );
  }
}

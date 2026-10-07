import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/route_observer.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/scenario/history_menu_screen.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
import 'package:jpn_learning_app/screens/article/article_list_screen.dart';

import 'package:jpn_learning_app/widgets/common/app_drawer.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'package:jpn_learning_app/services/push_service.dart';
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';
import 'package:jpn_learning_app/widgets/home/daily_goal_card.dart';
import 'package:jpn_learning_app/widgets/dialogs/vocab_bottom_sheet.dart';
import 'package:jpn_learning_app/widgets/home/recent_scenes_list.dart';
import 'package:jpn_learning_app/widgets/common/status_chip.dart';
import 'package:jpn_learning_app/screens/sentence/sentence_practice_screen.dart';

// 🌟 引入剛剛建立的作業清單畫面 (請確認路徑是否正確)
import 'package:jpn_learning_app/screens/edu/assignment_list_screen.dart';
import 'package:jpn_learning_app/screens/edu/classroom_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  int _currentIndex = 0;
  int? _lastUserId;
  List<dynamic> _recentScenes = [];
  List<Map<String, dynamic>> _myClassrooms = [];
  bool _isLoadingScenes = true;

  final Color _textColor = const Color(0xFF2C3E50);
  final Color _subTextColor = const Color(0xFF8E9AAB);
  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _brandColor = const Color(0xFF006D3E);

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
    if (!mounted) return;
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
    NotificationService.recordUserActive();
    await _checkPendingFriendRequests(userId);
    await _fetchRecentScenes(userId);
    await _fetchAndCheckBadgeProgress(userId);
    await _fetchUsageStatus(userId);
    await _fetchDailyStatus(userId);
    await _fetchMyClassrooms(userId);
  }

  Future<void> _fetchMyClassrooms(int userId) async {
    try {
      final classrooms = await ApiClient.getMyClassrooms(userId);
      if (!mounted) return;
      setState(() => _myClassrooms = classrooms);
    } catch (e) {
      debugPrint('教室清單載入失敗: $e');
    }
    if (!mounted) return;
    // 所有帳號都登記推播（學習小組的「提醒隊友」一般會員也會收到）
    PushService.register(userId);
    if (!context.read<UserProvider>().isEduStudent) return;
    // 校園教育版學生：排作業截止提醒、打開從通知點進來的頁面
    PushService.openPending();
    try {
      final assignments = await ApiClient.getStudentAssignments(userId);
      await NotificationService.scheduleAssignmentReminders(assignments);
    } catch (e) {
      debugPrint('作業截止提醒排程失敗: $e');
    }
  }

  Future<void> _fetchAndCheckBadgeProgress(int userId) async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    try {
      final result = await ApiClient.fetchProfileData(userId);
      if (!mounted) return;
      if (result.containsKey('badge_progress')) {
        userProvider.setBadgeProgress(
          result['badge_progress'] as Map<String, dynamic>,
        );
      }
      if (result.containsKey('j_pts')) {
        userProvider.setJPts((result['j_pts'] as num).toInt());
      }
      if (result.containsKey('streak_days')) {
        userProvider.setStreakDays((result['streak_days'] as num).toInt());
      }
      if (result.containsKey('avatar') && result['avatar'] != null) {
        userProvider.setAvatar(result['avatar'].toString());
      }
      if (result.containsKey('username') && result['username'] != null) {
        userProvider.setUsername(result['username'].toString());
      }
    } catch (e) {
      debugPrint('資料同步錯誤: $e');
    }
  }

  Future<void> _fetchRecentScenes(int userId) async {
    try {
      final scenes = await ApiClient.getUnlockedScenes(userId, limit: 3);
      if (!mounted) return;
      setState(() {
        _recentScenes = scenes;
        _isLoadingScenes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingScenes = false);
    }
  }

  Future<void> _checkPendingFriendRequests(int userId) async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    try {
      final result = await ApiClient.getPendingRequests(userId);
      if (result.containsKey('pending_requests')) {
        userProvider.setPendingFriendRequests(
          (result['pending_requests'] as List).length,
        );
      }
    } catch (e) {}
  }

  Future<void> _fetchUsageStatus(int userId) async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    try {
      final res = await ApiClient.getUsageStatus(userId);
      if (!mounted) return;
      userProvider.setUsageStatus(
        photoCountToday: (res['photo_count_today'] as num?)?.toInt() ?? 0,
        photoExtraCount: (res['photo_extra_count'] as num?)?.toInt() ?? 0,
        aiCountToday: (res['ai_count_today'] as num?)?.toInt() ?? 0,
        aiExtraCount: (res['ai_extra_count'] as num?)?.toInt() ?? 0,
        vocabSlot: (res['vocab_slot'] as num?)?.toInt() ?? 50,
        photoDailyLimit: (res['photo_daily_limit'] as num?)?.toInt(),
        aiDailyLimit: (res['ai_daily_limit'] as num?)?.toInt(),
        sentenceCountToday: (res['sentence_count_today'] as num?)?.toInt(),
        sentenceDailyLimit: (res['sentence_daily_limit'] as num?)?.toInt(),
        readingCountToday: (res['reading_count_today'] as num?)?.toInt(),
        readingDailyLimit: (res['reading_daily_limit'] as num?)?.toInt(),
        isPremium: res['is_premium'] == true,
        accountType: res['account_type']?.toString(),
      );
    } catch (e) {
      debugPrint('使用量載入失敗: $e');
    }
  }

  Future<void> _fetchDailyStatus(int userId) async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    try {
      final res = await ApiClient.getDailyStatus(userId);
      if (!mounted) return;
      if (res.containsKey('photo_done')) {
        final preview = res['reward_preview'] as Map<String, dynamic>? ?? {};
        userProvider.setDailyTaskStatus(
          photoDone: res['photo_done'] == true,
          aiDone: res['ai_done'] == true,
          sentenceDone: res['sentence_done'] == true,
          readingDone: res['reading_done'] == true,
          claimed: res['claimed'] == true,
          ptsMin: (preview['pts_min'] as num?)?.toInt() ?? 10,
          ptsMax: (preview['pts_max'] as num?)?.toInt() ?? 30,
          bonusPhoto: (preview['bonus_photo'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('每日任務狀態載入失敗: $e');
    }
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
    List<DateTime> weekDates = List.generate(
      7,
      (i) => firstDayOfWeek.add(Duration(days: i)),
    );
    List<String> weekDayNames = ['一', '二', '三', '四', '五', '六', '日'];

    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.displayName;
    final jPts = userProvider.jPts;
    final streakDays = userProvider.streakDays;
    final avatarUrl = userProvider.avatar;

    // 🌟 判斷是否為教育版學生
    final isEduStudent = userProvider.accountType == 'student';
    final hasClassrooms = _myClassrooms.isNotEmpty;
    // 各教室未讀公告加總，「我的教室」按鈕上顯示紅色數字
    final unreadNotices = _myClassrooms.fold<int>(
      0,
      (sum, c) => sum + ((c['unread_count'] as num?)?.toInt() ?? 0),
    );

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      extendBody: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _flatCanvasColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 30),
            color: AppColors.primary,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset(
          'assets/images/logo_snaptolearn-removebg-preview.png',
          height: 35,
          errorBuilder: (c, e, s) => Text(
            "Snap to Learn",
            style: TextStyle(color: _brandColor, fontWeight: FontWeight.w900),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
              child: Row(
                children: [
                  UserAvatar(
                    avatarBase64: avatarUrl,
                    friendId: userProvider.friendId,
                    originalName: userName,
                    radius: 35,
                    isPremium: userProvider.isPremium,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 14,
                            color: _subTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$userName!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: _textColor,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已連續登入 $streakDays 天',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 教育版學生沒有付費機制，點數標籤直接不顯示
                              if (!isEduStudent)
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const StoreDashboardScreen(
                                            initialIndex: 1,
                                          ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.monetization_on_outlined,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$jPts Pts',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildCheckInCalendarCard(weekDates, weekDayNames, streakDays),

            // 🌟 只有教育版學生才顯示「我的作業」按鈕 (Point 4 入口)
            if (isEduStudent)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text(
                      '我的作業',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2), // 教育版專屬藍色
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssignmentListScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 10),

            _buildSectionHeader('今日學習目標'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DailyGoalCard(onReturnFromCamera: () => _syncHomeData()),
            ),

            const SizedBox(height: 35),

            // 🌟 造句挑戰區塊
            _buildSectionHeader('AI 挑戰'),
            _buildSentencePracticeCard(context),

            const SizedBox(height: 35),

            _buildSectionHeader('文章練習'),
            _buildArticlePracticeCard(context),

            const SizedBox(height: 35),

            _buildSectionHeader('最近解鎖場景', hasGalleryLink: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: RecentScenesList(
                recentScenes: _recentScenes,
                isLoadingScenes: _isLoadingScenes,
                onShowVocabularyBottomSheet: (scene) => VocabBottomSheet.show(
                  context,
                  scene,
                  userProvider.userId?.toString(),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      // 教育版學生可查看已加入的教室，或前往加入教室。
      floatingActionButton: isEduStudent && userProvider.userId != null
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClassroomListScreen(),
                    ),
                  ).then((_) => _syncHomeData()),
                  icon: const Icon(
                    Icons.add_home_work_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    hasClassrooms ? '我的教室' : '加入教室',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.primaryLight2,
                ),
                // 未讀公告數：貼在整顆按鈕的右上角，像一般 App 的通知標記
                if (unreadNotices > 0)
                  Positioned(
                    right: -4,
                    top: -6,
                    child: IgnorePointer(
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          unreadNotices > 99 ? '99+' : '$unreadNotices',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 0) {
            // 已經在主頁
          } else if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            ).then((_) => _syncHomeData());
          } else if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
            ).then((_) => _syncHomeData());
          } else if (i == 3) {
            // 「紀錄」改為選單頁
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryMenuScreen()),
            ).then((_) => _syncHomeData());
          } else if (i == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _syncHomeData());
          }
        },
      ),
    );
  }

  Widget _buildSentencePracticeCard(BuildContext context) {
    const Color _cardGreen = Color(0xFF6AA86B);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SentencePracticeScreen(),
            ),
          ).then((_) => _syncHomeData());
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardGreen,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _cardGreen.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI 造句挑戰',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '活化單字本，賺取 J-pts！',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticlePracticeCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArticleListScreen()),
          ).then((_) => _syncHomeData());
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '閱讀文章',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '透過閱讀提升語感與單字量',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E9AAB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF8E9AAB).withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInCalendarCard(
    List<DateTime> weekDates,
    List<String> weekDayNames,
    int streakDays,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本週打卡',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = weekDates[index];
              final targetDate = DateTime(date.year, date.month, date.day);
              final isToday = targetDate.isAtSameMomentAs(today);
              final diffDays = today.difference(targetDate).inDays;
              bool isCompleted = diffDays >= 0 && diffDays < streakDays;

              return Column(
                children: [
                  Text(
                    weekDayNames[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: _subTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary
                          : (isCompleted
                                ? AppColors.primary.withOpacity(0.6)
                                : Colors.grey.withOpacity(0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              date.day.toString(),
                              style: TextStyle(
                                color: isToday ? Colors.white : _textColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
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
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 0.5,
            ),
          ),
          if (hasGalleryLink)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ResultGalleryV2Screen(),
                ),
              ).then((_) => _syncHomeData()),
              child: const Text(
                '查看全部 >',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

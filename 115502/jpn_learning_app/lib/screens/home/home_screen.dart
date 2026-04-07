/// 首頁畫面
/// 負責顯示學習應用的主要介面，包含：
/// - 用戶問候與狀態資訊（學習天數、點數）
/// - 每日學習目標進度
/// - 最近解鎖的學習場景列表
/// - 學習小組動態
/// - 徽章升級檢查與慶祝對話框
// ==========================================
// 1. 系統內建與第三方套件 (Core & Packages)
// ==========================================
import 'dart:ui';                                  // 處理毛玻璃模糊效果 (ImageFilter) 等底層 UI 功能
import 'package:flutter/material.dart';            // Flutter 核心 Material 設計元件庫
import 'package:provider/provider.dart';           // 狀態管理套件 (負責呼叫 context.watch 或 read)

// ==========================================
// 2. 常數、工具與 API (Utils & Services)
// ==========================================
import 'package:jpn_learning_app/utils/api_client.dart';       // 負責跟 Python 後端溝通的 API 外送員
import 'package:jpn_learning_app/utils/badge_utils.dart';      // 🏆 集中管理徽章門檻、顏色與等級計算的工具箱
import 'package:jpn_learning_app/utils/constants.dart';        // 全站共用常數設定 (例如 AppColors 主題色)

// ==========================================
// 3. 狀態管理 (Providers)
// ==========================================
import 'package:jpn_learning_app/providers/user_provider.dart';// 記住使用者當前狀態 (點數、連勝、徽章進度) 的專屬管家

// ==========================================
// 4. 畫面路由 (Screens - 切換頁面用)
// ==========================================
import 'package:jpn_learning_app/screens/auth/login_screen.dart';                  // 登入與註冊畫面
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';     // 學習小組排行榜與動態畫面
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';          // 購買 J-Pts 點數的商城畫面
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';             // 個人檔案、能力雷達圖與徽章庫畫面
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';             // AR 相機拍照辨識核心畫面
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';      // 手動輸入搜尋單字畫面
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';  // 我的單字探險 (相簿/收藏夾) 總覽畫面

// ==========================================
// 5. 獨立 UI 元件與彈出視窗 (Widgets & Dialogs - 組成首頁的樂高積木)
// ==========================================
import 'package:jpn_learning_app/widgets/common/app_drawer.dart';               // 左側滑出的漢堡選單
import 'package:jpn_learning_app/widgets/common/bottom_nav_bar.dart';           // App 底部的五顆導覽按鈕
import 'package:jpn_learning_app/widgets/home/daily_goal_card.dart';            // 首頁綠色的「今日學習目標」卡片
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';         // 🎉 華麗的徽章升級慶祝彈窗
import 'package:jpn_learning_app/widgets/dialogs/vocab_bottom_sheet.dart';      // 點擊場景後，從底部滑出的單字清單
import 'package:jpn_learning_app/widgets/common/premium_locked_overlay.dart';   // 訪客未登入時，蓋在卡片上的「毛玻璃上鎖」遮罩
import 'package:jpn_learning_app/widgets/home/recent_scenes_list.dart';         // 首頁橫向滑動的「最近解鎖場景」列表
import 'package:jpn_learning_app/widgets/common/status_chip.dart';             // 首頁上方顯示連勝天數、點數的小膠囊標籤
import 'package:jpn_learning_app/widgets/home/study_group_card.dart';          // 首頁顯示朋友獲得徽章動態的卡片

/// 首頁畫面狀態管理類別
/// 負責管理首頁的所有狀態和業務邏輯
class HomeScreen extends StatefulWidget {
  /// 建構子
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
      _fetchAndCheckBadgeProgress(); // 首頁載入時檢查是否升級
    });
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
    if (userId == null) return; // 訪客不檢查

    // 1. 紀錄舊的狀態 (使用 BadgeUtils 解析舊等級)
    final int oldJpLevel = BadgeUtils.japaneseLevelToNumber(userProvider.japaneseLevel);
    final Map<String, int> oldProgress = Map<String, int>.from(userProvider.badgeProgress);

    try {
      final result = await ApiClient.fetchProfileData(userId);
      
      if (!mounted) return;

      if (result.containsKey('badge_progress')) {
        final newProgress = result['badge_progress'] as Map<String, dynamic>;
        
        // 假設 API 的 profile 資料裡有回傳 japanese_level
        final String? newJpLevelStr = result['japanese_level']; 
        final int newJpLevel = BadgeUtils.japaneseLevelToNumber(newJpLevelStr);

        // 2. 只有在「舊進度不是空的」或是「新註冊剛測驗完」的情況下才彈窗
        bool hasInitialData = oldProgress.isNotEmpty || oldJpLevel > 0;

        // --- 檢查「程度認證」徽章 (新註冊測驗後適用) ---
        if (newJpLevel > oldJpLevel) {
          await LevelUpDialog.show(context, badgeId: 'level_01', level: newJpLevel);
        }

        // --- 檢查「其他 4 大核心徽章」 (拍照、連勝等) ---
        if (hasInitialData) {
          // 注意這裡：改用 BadgeUtils.milestones.keys 拿取所有徽章 ID
          for (String id in BadgeUtils.milestones.keys) {
            if (id == 'level_01') continue; // 跳過已經獨立檢查過的程度認證

            int oldVal = oldProgress[id] ?? 0;
            int newVal = newProgress[id] is int ? newProgress[id] : (newProgress[id] as num?)?.toInt() ?? 0;

            // 注意這裡：改用 BadgeUtils 裡的計算方法，不用自己算了！
            int oldLevel = BadgeUtils.calculateLevel(oldVal, id);
            int newLevel = BadgeUtils.calculateLevel(newVal, id);

            // 如果等級變高了，就叫出慶祝彈窗！
            if (newLevel > oldLevel) {
              await LevelUpDialog.show(context, badgeId: id, level: newLevel);
            }
          }
        }
        
        // 3. 最後同步更新 Provider 裡的資料
        if (newJpLevelStr != null) {
          userProvider.setJapaneseLevel(newJpLevelStr);
        }
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
              onShowVocabularyBottomSheet: (scene) => VocabBottomSheet.show(context, scene, context.read<UserProvider>().userId?.toString()),
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
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 工具與 Provider
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 2. 共用元件
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';

// 3. 畫面 Screens
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/profile/profile_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';

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

  // 集中管理徽章門檻與資訊 (為了計算升級彈窗)
  final Map<String, List<int>> _badgeMilestones = {
    'level_01': [1, 2, 3, 4, 5],
    'vocab_01': [10, 50, 100, 300, 500],
    'streak_01': [3, 7, 14, 30, 60],
    'marathon_01': [5, 15, 50, 100, 200],
    'camera_01': [10, 50, 200, 500, 1000],
  };

  final Map<String, Map<String, dynamic>> _badgeInfo = {
    'level_01': {'title': '程度認證', 'icon': Icons.school},
    'vocab_01': {'title': '單字大富翁', 'icon': Icons.menu_book},
    'streak_01': {'title': '學習火種', 'icon': Icons.local_fire_department},
    'marathon_01': {'title': '學習馬拉松', 'icon': Icons.directions_run},
    'camera_01': {'title': '快門獵人', 'icon': Icons.camera_alt},
  };

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
          for (String id in _badgeMilestones.keys) {
            int oldVal = oldProgress[id] ?? 0;
            int newVal = newProgress[id] is int ? newProgress[id] : (newProgress[id] as num?)?.toInt() ?? 0;

            int oldLevel = _calculateLevel(oldVal, _badgeMilestones[id]!);
            int newLevel = _calculateLevel(newVal, _badgeMilestones[id]!);

            // 如果等級變高了，就叫出慶祝彈窗！
            if (newLevel > oldLevel) {
              if (mounted) await _showLevelUpDialog(id, newLevel);
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
  
  int _calculateLevel(int progress, List<int> ms) {
    int level = 0;
    for (int i = 0; i < ms.length; i++) {
      if (progress >= ms[i]) level = i + 1;
      else break;
    }
    return level;
  }

  Map<String, dynamic> _getLevelTheme(int level) {
    switch (level) {
      case 5: return {'name': '白金級', 'color': Colors.purpleAccent, 'isGradient': true};
      case 4: return {'name': '金牌', 'color': Colors.amber[400]!, 'isGradient': false};
      case 3: return {'name': '銀牌', 'color': Colors.blueGrey[300]!, 'isGradient': false};
      case 2: return {'name': '銅牌', 'color': Colors.orange[700]!, 'isGradient': false};
      case 1: return {'name': '初階', 'color': Colors.brown[400]!, 'isGradient': false};
      default: return {'name': '未解鎖', 'color': Colors.grey[400]!, 'isGradient': false};
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '早安';
    if (hour >= 12 && hour < 18) return '午安';
    return '晚安';
  }

  // 升級慶祝彈窗
  Future<void> _showLevelUpDialog(String id, int level) async {
    final info = _badgeInfo[id]!;
    final theme = _getLevelTheme(level);
    final bool isGradient = theme['isGradient'];
    final Color solidColor = isGradient ? Colors.white : theme['color'];

    await showGeneralDialog(
      context: context,
      barrierDismissible: false, 
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.7), 
      transitionDuration: const Duration(milliseconds: 600), 
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            contentPadding: const EdgeInsets.all(32),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉 恭喜升級 🎉', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: solidColor.withOpacity(0.15),
                    gradient: isGradient ? const SweepGradient(colors: [Colors.purple, Colors.blue, Colors.pink, Colors.purple]) : null,
                    border: !isGradient ? Border.all(color: solidColor, width: 4) : null,
                    boxShadow: [BoxShadow(color: (isGradient ? Colors.purple : solidColor).withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: isGradient
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: Icon(info['icon'] as IconData, color: Colors.purple, size: 60),
                        )
                      : Icon(info['icon'] as IconData, color: solidColor, size: 70),
                ),
                const SizedBox(height: 28),
                Text(info['title'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('已解鎖【${theme['name']}】', style: TextStyle(fontSize: 18, color: isGradient ? Colors.purple : solidColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('你的努力有了回報！繼續保持下去！', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7C59),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('太棒了！', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVocabularyBottomSheet(BuildContext context, dynamic scene) {
    final userId = context.read<UserProvider>().userId;
    
    // 如果尚未登入 (userId 為 null)，直接提示並擋下，避免報錯
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能查看單字解鎖進度喔！')),
      );
      return; 
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${scene['scene_name']} 的單字', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              // 動態載入單字清單
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: FutureBuilder<List<dynamic>>(
                  future: ApiClient.getSceneVocabs(scene['scene_id'], userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("載入單字失敗"));
                    }
                    
                    final vocabs = snapshot.data ?? [];
                    if (vocabs.isEmpty) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("這個場景還沒有單字喔！")));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: vocabs.length,
                      itemBuilder: (context, index) {
                        final vocab = vocabs[index];
                        final isUnlocked = vocab['is_unlocked'] == true;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                isUnlocked ? Icons.check_circle : Icons.radio_button_unchecked, 
                                color: isUnlocked ? const Color(0xFF6AA86B) : Colors.grey.shade400
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  '${vocab['word']} (${vocab['meaning']})', 
                                  style: TextStyle(
                                    fontSize: 16, 
                                    color: isUnlocked ? _textColor : Colors.grey.shade500
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 4. UI 區塊元件 (Widgets)
  // ==========================================
  
  Widget _buildRecentScenesList() {
    if (_isLoadingScenes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recentScenes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("還沒有解鎖的場景，趕快去拍照探索吧！", style: TextStyle(color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(
            _recentScenes.length,
            (index) {
              final scene = _recentScenes[index];
              final isEven = index % 2 == 0; // 判斷單雙數來變換卡片顏色

              return GestureDetector(
                onTap: () => _showVocabularyBottomSheet(context, scene),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isEven ? const Color(0xFFEBE8F2) : const Color(0xFFEAF4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isEven ? const Color(0xFF8B6B9E) : const Color(0xFF7FAFD0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.train, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        scene['scene_name'] ?? '未知場景',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${scene['unlocked_at']} • ${scene['vocab_count']}個單字',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLockedOverlay({required Widget child, required String message}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.35, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: Container(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: _goalGreen, borderRadius: BorderRadius.circular(20)),
                  child: const Text('去登入', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyGoalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _goalGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _goalGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('探索3個新場景', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (context.watch<UserProvider>().dailyScans / 3.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('進度 : ${context.watch<UserProvider>().dailyScans}/3', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _goalGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  elevation: 0,
                ),
                child: const Row(
                  children: [
                    Text('開啟相機', style: TextStyle(fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward_outlined, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudyGroupCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.amber.shade100,
            child: const Text('D', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Din', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('獲得了「麵食大師」徽章', style: TextStyle(fontSize: 13, color: _subTextColor)),
              ],
            ),
          ),
          Text('10m', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required IconData icon, required Color iconColor, required String text, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(20), color: Colors.white),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
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
                _buildStatusChip(
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
                  child: _buildStatusChip(
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
                ? _buildPremiumLockedOverlay(child: _buildDailyGoalCard(context), message: '登入啟用今日目標')
                : _buildDailyGoalCard(context),
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
            _buildRecentScenesList(),
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
                ? _buildPremiumLockedOverlay(child: _buildStudyGroupCard(context), message: '登入查看群組動態')
                : GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen())),
                    child: _buildStudyGroupCard(context),
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
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 工具與 Provider
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/providers/font_size_provider.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';

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
  // 生命週期與初始化
  // ==========================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingFriendRequests();
    });
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
      print('檢查好友邀請失敗: $e');
    }
  }

  // ==========================================
  // 輔助函式
  // ==========================================
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '早安';
    if (hour >= 12 && hour < 18) return '午安';
    return '晚安';
  }

  // 從底部彈出單字清單的函式 (首頁輕量複習專用)
  void _showVocabularyBottomSheet(BuildContext context, dynamic scenario) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允許內容自訂高度
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 高度根據內容自動縮放
            children: [
              // 頂部視覺小橫條
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              // 標題與關閉按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${scenario.title} 的單字',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              // 單字列表 (限制最高只能佔螢幕一半，超過可滑動)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: scenario.vocabularyList.length,
                  itemBuilder: (context, index) {
                    final vocab = scenario.vocabularyList[index];
                    
                    // ⚠️ 注意：如果你的單字資料結構不同，請把下面的 .word 和 .translation 換成你實際的變數寫法！
                    // 例如如果它是 Map，可能會寫成 vocab['word']
                    final String wordText = vocab.word ?? '未知單字';
                    final String translationText = vocab.translation ?? '未知中文';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF6AA86B)), // 綠色勾勾
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '$wordText ($translationText)', 
                              style: TextStyle(fontSize: 16, color: _textColor),
                            ),
                          ),
                        ],
                      ),
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
  // UI 區塊構建
  // ==========================================
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
  // 主畫面 Build
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(
                    FavoritesDataProvider.allFavorites.take(5).length,
                    (index) {
                      final scenario = FavoritesDataProvider.allFavorites[index];
                      return GestureDetector(
                        // 點擊後從下方彈出輕量級單字清單，不再跳轉到詳細相簿！
                        onTap: () => _showVocabularyBottomSheet(context, scenario),
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? const Color(0xFFEBE8F2) : const Color(0xFFEAF4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0 ? const Color(0xFF8B6B9E) : const Color(0xFF7FAFD0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.train, color: Colors.white, size: 24),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                scenario.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${scenario.date} • ${scenario.vocabularyList.length}個單字',
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
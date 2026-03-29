import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import 'photo_folder_v2_screen.dart';
import 'badge_library_screen.dart'; // 👈 引入徽章庫

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color _bgColor = Colors.white;
  final Color _cardColor = const Color(0xFFF1F8E9);
  final Color _primaryGreen = const Color.fromARGB(255, 74, 124, 89);
  final Color _textColor = const Color(0xFF333333);

  bool _isLoading = true;
  List<double> _radarValues = [0.2, 0.2, 0.2, 0.2, 0.2];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final userId = context.read<UserProvider>().userId;

    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
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
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('抓取資料失敗，請稍後再試')));
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訪客無法修改大頭貼，請先註冊或登入喔！')));
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

  Future<void> _editNickname(String currentName) async {
    final userId = context.read<UserProvider>().userId;
    final controller = TextEditingController(text: context.read<UserProvider>().username ?? '');
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
                final check = await ApiClient.checkUsername(name, userId: userId);
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
              child: Text('確認', style: TextStyle(color: _primaryGreen)),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || userId == null) return;

    final res = await ApiClient.updateUsername(userId, result);
    if (!mounted) return;

    if (res['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'])),
      );
      return;
    }

    context.read<UserProvider>().setUsername(result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暱稱已更新')),
    );
  }

  void _handleGuestClick(String featureName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('訪客無法使用「$featureName」功能，請先登入喔！')));
  }

  // --- 新版首頁成就區塊 (點擊進入徽章庫) ---
  Widget _buildAchievementsSection(BuildContext context, bool isGuest) {
    final userProvider = Provider.of<UserProvider>(context);
    final unlockedCount = isGuest ? 0 : userProvider.unlockedBadgeIds.length;

    return GestureDetector(
      onTap: () {
        if (isGuest) {
          _handleGuestClick('成就徽章庫');
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BadgeLibraryScreen()),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '成就徽章',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$unlockedCount 個已解鎖',
                      style: TextStyle(
                        color: _primaryGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: _primaryGreen),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 展示前三個代表性徽章
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniBadge(
                  Icons.ramen_dining,
                  '拉麵大師',
                  isGuest ? false : userProvider.isBadgeUnlocked('ramen_01'),
                ),
                _buildMiniBadge(
                  Icons.restaurant,
                  '美食導航員',
                  isGuest ? false : userProvider.isBadgeUnlocked('food_01'),
                ),
                _buildMiniBadge(
                  Icons.menu_book,
                  '語法通',
                  isGuest ? false : userProvider.isBadgeUnlocked('grammar_01'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 首頁用的迷你徽章 UI
  Widget _buildMiniBadge(IconData icon, String title, bool isUnlocked) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked ? const Color(0xFFC5E1A5) : Colors.grey[300],
          ),
          child: Icon(
            isUnlocked ? icon : Icons.lock,
            color: isUnlocked ? _primaryGreen : Colors.grey[500],
            size: 28,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isUnlocked ? _textColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail =
        context.watch<UserProvider>().email ?? 'guest@example.com';
    final userName = context.watch<UserProvider>().username ??
        userEmail.split('@')[0];
    final userAvatar = context.watch<UserProvider>().avatar;
    final isGuest = context.watch<UserProvider>().userId == null;

    final List<String> colors = [
      'E57373',
      'F06292',
      'BA68C8',
      '9575CD',
      '7986CB',
      '64B5F6',
      '4DD0E1',
      '4DB6AC',
      '81C784',
      'AED581',
      'FFB74D',
      'FF8A65',
    ];
    final String safeName = userName.isEmpty ? 'Guest' : userName;

    int hash = 0;
    for (int i = 0; i < safeName.length; i++) {
      hash = (hash * 31 + safeName.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final String bgColor = colors.isNotEmpty
        ? colors[hash % colors.length]
        : '000000';

    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(safeName)}&background=$bgColor&color=fff';

    return Scaffold(
      backgroundColor: _bgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFFC5E1A5),
                                backgroundImage:
                                    (userAvatar != null &&
                                        userAvatar.isNotEmpty)
                                    ? (userAvatar.startsWith('http')
                                        ? NetworkImage(userAvatar)
                                        : MemoryImage(base64Decode(userAvatar)) as ImageProvider)
                                    : NetworkImage(defaultAvatarUrl)
                                          as ImageProvider,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _primaryGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: isGuest ? null : () => _editNickname(userName),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      isGuest ? '訪客' : userName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isGuest) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isGuest
                                  ? '登入解鎖更多功能'
                                  : context.watch<UserProvider>().japaneseLevel.isNotEmpty
                                      ? context.watch<UserProvider>().japaneseLevel
                                      : '尚未設定等級',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: isGuest ? 0.0 : 0.3,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation(
                                  _primaryGreen,
                                ),
                                minHeight: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 能力雷達圖區塊
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '能力',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: SizedBox(
                                width: 200,
                                height: 200,
                                child: CustomPaint(
                                  painter: RadarChartPainter(
                                    color: _primaryGreen,
                                    values: _radarValues,
                                  ),
                                ),
                              ),
                            ),
                            if (isGuest)
                              Container(
                                width: double.infinity,
                                height: 220,
                                color: Colors.white.withOpacity(0.7),
                                child: Center(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                        255,
                                        74,
                                        124,
                                        89,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      '登入查看能力分析',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 👈 替換為新的成就徽章區塊
                  _buildAchievementsSection(context, isGuest),
                  const SizedBox(height: 24),

                  // 收藏夾區塊
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '收藏夾',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (isGuest) {
                              _handleGuestClick('收藏夾');
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PhotoFolderV2Screen(),
                                ),
                              );
                            }
                          },
                          child: Text(
                            '查看全部 >',
                            style: TextStyle(
                              color: _primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4,
        onTap: (i) {
          if (i == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          } else if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
            );
          } else if (i == 2) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          } else if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudyGroupScreen()),
            );
          }
        },
      ),
    );
  }
}

// 雷達圖繪製 (保留不變)
class RadarChartPainter extends CustomPainter {
  final Color color;
  final List<double> values;
  RadarChartPainter({required this.color, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = math.min(centerX, centerY) - 30;

    final Paint gridPaint = Paint()
      ..color = Colors.green.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int step = 1; step <= 3; step++) {
      final Path path = Path();
      for (int i = 0; i < 5; i++) {
        double angle = (math.pi * 2 / 5) * i - math.pi / 2;
        double currentRadius = radius * (step / 3);
        double x = centerX + currentRadius * math.cos(angle);
        double y = centerY + currentRadius * math.sin(angle);
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (int i = 0; i < 5; i++) {
      double angle = (math.pi * 2 / 5) * i - math.pi / 2;
      double x = centerX + radius * math.cos(angle);
      double y = centerY + radius * math.sin(angle);
      canvas.drawLine(Offset(centerX, centerY), Offset(x, y), gridPaint);
    }

    final Path valuePath = Path();
    final Paint valuePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final Paint valueStrokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 5; i++) {
      double angle = (math.pi * 2 / 5) * i - math.pi / 2;
      double valueRadius = radius * values[i];
      double x = centerX + valueRadius * math.cos(angle);
      double y = centerY + valueRadius * math.sin(angle);
      if (i == 0)
        valuePath.moveTo(x, y);
      else
        valuePath.lineTo(x, y);
    }
    valuePath.close();
    canvas.drawPath(valuePath, valuePaint);
    canvas.drawPath(valuePath, valueStrokePaint);

    final List<String> labels = [
      'Listening',
      'Speaking',
      'Reading',
      'Writing',
      'Culture',
    ];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 5; i++) {
      double angle = (math.pi * 2 / 5) * i - math.pi / 2;
      double textRadius = radius + 15;
      double x = centerX + textRadius * math.cos(angle);
      double y = centerY + textRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.black87, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

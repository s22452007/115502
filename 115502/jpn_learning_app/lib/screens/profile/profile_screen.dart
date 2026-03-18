import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'photo_folder_v2_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 4;
  final Color _bgColor = Colors.white;
  final Color _cardColor = const Color(0xFFF1F8E9);
  final Color _primaryGreen = const Color.fromARGB(255, 74, 124, 89);
  final Color _textColor = const Color(0xFF333333);

  // 用來存放從後端抓來的資料
  bool _isLoading = true;
  List<double> _radarValues = [0.2, 0.2, 0.2, 0.2, 0.2]; // 預設值
  List<dynamic> _achievements = []; // 存放徽章清單

  @override
  void initState() {
    super.initState();
    // 畫面一載入，就去抓資料
    _fetchData();
  }

  Future<void> _fetchData() async {
    // 這裡我們不能直接用 context.watch，因為它只能放在 build 裡面
    // 在 initState 裡要用 context.read
    final userId = context.read<UserProvider>().userId;

    if (userId == null) {
      // 【訪客防呆機制】如果是訪客，就不抓資料，直接顯示預設值並結束 loading
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final result = await ApiClient.fetchProfileData(userId);
    if (!mounted) return;

    if (result.containsKey('ability')) {
      setState(() {
        // 按照雷達圖的順序：[Listening, Speaking, Reading, Writing, Culture]
        _radarValues = [
          result['ability']['listening'].toDouble(),
          result['ability']['speaking'].toDouble(),
          result['ability']['reading'].toDouble(),
          result['ability']['writing'].toDouble(),
          result['ability']['culture'].toDouble(),
        ];
        _achievements = result['achievements'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false; // 就算失敗也要把轉圈圈關掉
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

  // 用來處理點擊「訪客不能用的功能」的提示
  void _handleGuestClick(String featureName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('訪客無法使用「$featureName」功能，請先登入喔！')));
  }

  // 動態產生徽章的輔助函式
  Widget _buildAchievementsGrid(bool isGuest) {
    if (isGuest) {
      // 如果是訪客，顯示 3 個鎖住的假徽章
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBadge(
            icon: Icons.lock,
            label: '請先登入',
            isUnlocked: false,
            isGuest: true,
          ),
          _buildBadge(
            icon: Icons.lock,
            label: '請先登入',
            isUnlocked: false,
            isGuest: true,
          ),
          _buildBadge(
            icon: Icons.lock,
            label: '請先登入',
            isUnlocked: false,
            isGuest: true,
          ),
        ],
      );
    }

    if (_achievements.isEmpty) return const Text('目前沒有成就資料');

    // 根據後端回傳的資料，動態產生徽章清單 (每列 3 個)
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.spaceAround,
      children: _achievements.map((ach) {
        // 這裡做一個簡單的圖示對應 (你可以之後自己擴充)
        IconData iconData = Icons.star;
        if (ach['name'].contains('拉麵')) iconData = Icons.ramen_dining;
        if (ach['name'].contains('交通')) iconData = Icons.train;
        if (ach['name'].contains('文化')) iconData = Icons.temple_buddhist;

        return _buildBadge(
          icon: iconData,
          label: ach['name'],
          isUnlocked: ach['is_unlocked'],
          isGuest: false,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail =
        context.watch<UserProvider>().email ?? 'guest@example.com';
    final userName = userEmail.split('@')[0];
    final userAvatar = context.watch<UserProvider>().avatar;
    final isGuest = context.watch<UserProvider>().userId == null; // 判斷是否為訪客

    // 產生自己的專屬預設頭像網址
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
    int hash = 0;
    for (int i = 0; i < userName.length; i++)
      hash = (hash * 31 + userName.codeUnitAt(i)) & 0x7FFFFFFF;
    final String bgColor = colors[hash % colors.length];

    final String defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=$bgColor&color=fff';
    return Scaffold(
      backgroundColor: _bgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: _primaryGreen),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: IconButton(
          icon: Icon(Icons.camera_alt_outlined, color: _primaryGreen, size: 28),
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
            icon: Icon(Icons.person, color: _primaryGreen),
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
                            // 這裡換成有白框、支援專屬預設圖的 CircleAvatar
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
                                    ? MemoryImage(base64Decode(userAvatar))
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
                            Row(
                              children: [
                                Text(
                                  isGuest ? 'Lv.?' : 'Lv.3',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isGuest ? '訪客' : userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: isGuest ? 0.0 : 0.3, // 訪客沒進度
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
                                    onPressed: () => _handleGuestClick('能力分析'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryGreen,
                                    ),
                                    child: const Text(
                                      '登入查看能力分析',
                                      style: TextStyle(color: Colors.white),
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

                  // 成就區塊
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
                          '成就',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(child: _buildAchievementsGrid(isGuest)),
                      ],
                    ),
                  ),
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
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          }
          if (i == 2) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required bool isUnlocked,
    required bool isGuest,
  }) {
    return GestureDetector(
      onTap: () {
        if (isGuest) {
          _handleGuestClick('成就解鎖');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isUnlocked ? '你獲得了「$label」徽章！' : '多探索新場景來解鎖此徽章吧！'),
            ),
          );
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isUnlocked
                ? const Color(0xFFC5E1A5)
                : Colors.grey.shade300,
            child: Icon(
              icon,
              size: 30,
              color: isUnlocked ? _textColor : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isUnlocked ? _textColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// 雷達圖繪製 (保持不變)
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

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
// 🌟 我先把會報錯的檔案註解掉了，等你未來建好檔案再打開！
// import 'package:jpn_learning_app/screens/profile/photo_folder_screen.dart';
// import 'package:jpn_learning_app/screens/scenario/result_gallery_screen.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 4; // 底部導覽列對應個人檔案 (index 4)

  // 顏色設定
  final Color _bgColor = Colors.white;
  final Color _cardColor = const Color(0xFFF1F8E9);
  final Color _primaryGreen = const Color(0xFF6AA86B);
  final Color _textColor = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,

      drawer: _buildDrawer(context),

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
              MaterialPageRoute(builder: (_) => const CameraScreen()),
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

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFC5E1A5),
                  child: Icon(Icons.person, size: 50, color: _textColor),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Lv.3',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Yu',
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
                          value: 0.3,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(_primaryGreen),
                          minHeight: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

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
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: RadarChartPainter(
                          color: _primaryGreen,
                          values: [0.8, 0.6, 0.9, 0.5, 0.7],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBadge(
                        icon: Icons.ramen_dining,
                        label: '拉麵大師',
                        isUnlocked: true,
                      ),
                      _buildBadge(
                        icon: Icons.local_cafe,
                        label: '咖啡廳大師',
                        isUnlocked: true,
                      ),
                      _buildBadge(
                        icon: Icons.temple_buddhist,
                        label: '文化',
                        isUnlocked: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBadge(
                        icon: Icons.lock,
                        label: '未解鎖',
                        isUnlocked: false,
                      ),
                      _buildBadge(
                        icon: Icons.lock,
                        label: '未解鎖',
                        isUnlocked: false,
                      ),
                      _buildBadge(
                        icon: Icons.lock,
                        label: '未解鎖',
                        isUnlocked: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
                      // 🌟 安全起見，先改成跳出提示，等你建好檔案再換回來！
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('收藏夾功能即將推出！')),
                      );
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
          if (i == 0)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          if (i == 2) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required bool isUnlocked,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUnlocked ? '你獲得了「$label」徽章！' : '多探索新場景來解鎖此徽章吧！'),
          ),
        );
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: _primaryGreen),
            accountName: const Text(
              'Yu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text('yu_learning@example.com'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                'Y',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFF6AA86B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('回首頁', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('我的單字探險', style: TextStyle(fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              // 🌟 安全起見，先改成跳出提示
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('單字探險畫廊即將推出！')));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('系統設定', style: TextStyle(fontSize: 16)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

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
      '換一個',
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

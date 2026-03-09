import 'package:flutter/material.dart';

// 之後你要換成你專案裡的 AppColors.primary
const Color _primaryColor = Color(0xFF4CAF50);
const Color _backgroundColor = Colors.white;
const Color _textColor = Color(0xFF757575);

class ResultGalleryScreen extends StatefulWidget {
  const ResultGalleryScreen({super.key});

  @override
  State<ResultGalleryScreen> createState() => _ResultGalleryScreenState();
}

class _ResultGalleryScreenState extends State<ResultGalleryScreen> {
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _mockScanResults = [
    {
      'id': '1',
      'imagePath': 'assets/images/menu1.png',
      'location': '道頓堀 - 居酒屋',
      'words': ['お好み焼き (大阪燒)', '生ビール (生啤酒)'],
    },
    {
      'id': '2',
      'imagePath': 'assets/images/menu2.png',
      'location': '京都 - 宇治抹茶店',
      'words': ['抹茶 (Matcha)', '和菓子 (日式點心)'],
    },
  ];

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = _mockScanResults.length + 1;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('我的單字探險', style: TextStyle(color: Colors.black87)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87), // 讓返回鍵變黑色
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: LinearProgressIndicator(
              value: totalPages > 1 ? (_currentPage + 1) / totalPages : 1,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 6,
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPages,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                if (index < _mockScanResults.length) {
                  return _buildResultPage(_mockScanResults[index]);
                } else {
                  return _buildAddMorePage(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPage(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              size: 100,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: _primaryColor),
              const SizedBox(width: 4),
              Text(
                data['location'],
                style: const TextStyle(color: _textColor, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '💡 偵測到實用單字',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ...data['words']
              .map(
                (word) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[100]!),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.translate, color: _primaryColor),
                    title: Text(word, style: const TextStyle(fontSize: 16)),
                    trailing: const Icon(Icons.volume_up, color: _textColor),
                  ),
                ),
              )
              .toList(),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                print('進入角色扮演：${data['location']}');
              },
              icon: const Icon(Icons.star, color: Colors.white),
              label: const Text(
                '用這張菜單角色扮演點餐',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMorePage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40.0),
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '沒有更多單字照片了',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.2),
                      spreadRadius: 10,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: _primaryColor, width: 4),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 60, color: _primaryColor),
                    SizedBox(height: 16),
                    Text(
                      '新增單字照片',
                      style: TextStyle(
                        fontSize: 18,
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

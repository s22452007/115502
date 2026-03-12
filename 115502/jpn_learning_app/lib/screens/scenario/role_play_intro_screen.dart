import 'package:flutter/material.dart';

class RolePlayIntroScreen extends StatefulWidget {
  const RolePlayIntroScreen({super.key});

  @override
  State<RolePlayIntroScreen> createState() => _RolePlayIntroScreenState();
}

class _RolePlayIntroScreenState extends State<RolePlayIntroScreen> {
  // 控制滑動卡片，viewportFraction 讓左右卡片露出一點邊緣
  final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 【終極防呆】直接把 Scaffold 的底色變成綠色，這樣最下方絕對不可能出現白底！
    return Scaffold(
      backgroundColor: const Color(0xFFCDE8CD),
      body: Column(
        children: [
          // --- 1. 上半部：背景圖片 ---
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4, // 圖片佔畫面高度 40%
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 這裡我先放了一張網路上的居酒屋圖片，你可以換成自己的
                Image.network(
                  'https://images.unsplash.com/photo-1542051812891-60521138a209?q=80&w=800&auto=format&fit=crop',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey[800]),
                ),
                // 左上角返回按鈕
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. 下半部：綠色區域與白色單字卡 ---
          // 用 Expanded 強制填滿下方所有剩下的空間
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFCDE8CD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // 頂部小灰條
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 【白色單字卡滑動區】
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 3, // 預設 3 張卡片
                      itemBuilder: (context, index) {
                        return _buildWhiteCard();
                      },
                    ),
                  ),

                  // 【底部按鈕】
                  Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom:
                          MediaQuery.of(context).padding.bottom +
                          24, // 避開手機底部橫條
                      top: 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF558B4F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          print('進入角色扮演！');
                        },
                        child: const Text(
                          'Start Role-Play',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 獨立出來的「白色單字卡」區塊 ---
  Widget _buildWhiteCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white, // 【重點】確保這裡是白色的！
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('おんせん', style: TextStyle(color: Colors.grey, fontSize: 14)),
          SizedBox(height: 4),
          Text(
            'お勘定',
            style: TextStyle(
              color: Color(0xFF1B4E26),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '結帳',
            style: TextStyle(
              color: Color(0xFF1B4E26),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
          ),

          Text(
            'すみません、',
            style: TextStyle(
              color: Color(0xFF8B5A2B),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Excuse me,',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(height: 12),
          Text(
            'お勘定お願いします。',
            style: TextStyle(
              color: Color(0xFF8B5A2B),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Can I have the bill please?',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

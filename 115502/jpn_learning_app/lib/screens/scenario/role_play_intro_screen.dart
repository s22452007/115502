import 'package:flutter/material.dart';

class RolePlayIntroScreen extends StatefulWidget {
  const RolePlayIntroScreen({super.key});

  @override
  State<RolePlayIntroScreen> createState() => _RolePlayIntroScreenState();
}

class _RolePlayIntroScreenState extends State<RolePlayIntroScreen> {
  // 【關鍵修改】設定 viewportFraction 讓左右兩邊的卡片可以露出一部分
  final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color cardBgColor = Color(0xFFCDE8CD); // 淺綠色底板
    const Color buttonColor = Color(0xFF558B4F); // 深綠色按鈕

    return Scaffold(
      body: Stack(
        children: [
          // 1. 上半部：居酒屋背景圖片
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.45, // 調整比例讓圖片露多一點
            child: Container(
              color: Colors.grey[800],
              child: const Center(
                child: Icon(Icons.restaurant, size: 80, color: Colors.white54),
              ),
              // 有真實圖片後，把上面代碼註解掉，換成這行：
              // child: Image.asset('assets/images/izakaya_bg.png', fit: BoxFit.cover),
            ),
          ),

          // 左上角返回按鈕 (移到 Stack 的最外層，確保不會被圖片或綠色卡片蓋住)
          Positioned(
            top: 50, // 避開上方瀏海 (SafeArea)
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 2. 下半部：綠色圓角卡片區域
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: cardBgColor,
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
                  const SizedBox(height: 24),

                  // 3. 【關鍵修改】中間的白色單字學習卡，改為 PageView
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 3, // 假設有 3 個單字可以滑動
                      itemBuilder: (context, index) {
                        return _buildWordCard(); // 呼叫下方建立卡片的函數
                      },
                    ),
                  ),

                  // 4. 底部的 Start Role-Play 按鈕
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 32,
                      top: 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
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

  // 獨立抽出的白底單字卡 Widget
  Widget _buildWordCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
      ), // 左右間距，配合 viewportFraction 產生分離感
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          const Text(
            'おんせん',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'お勘定',
            style: TextStyle(
              color: Color(0xFF1B4E26),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '結帳',
            style: TextStyle(
              color: Color(0xFF1B4E26),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
          ),

          const Text(
            'すみません、',
            style: TextStyle(
              color: Color(0xFF8B5A2B),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Excuse me,',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            'お勘定お願いします。',
            style: TextStyle(
              color: Color(0xFF8B5A2B),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Can I have the bill please?',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

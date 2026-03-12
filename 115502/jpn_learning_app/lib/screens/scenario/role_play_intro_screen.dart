import 'package:flutter/material.dart';

class RolePlayIntroScreen extends StatefulWidget {
  // 🌟 魔法變數：這裡用來接收使用者提供的照片！
  // 未來在上一頁導航過來時，只要把照片路徑傳給它就行了
  final String imagePath;

  const RolePlayIntroScreen({
    Key? key,
    // 先預設一張超有 Fu 的居酒屋網頁圖片，方便你現在看效果
    // 等你要串接真實資料時，再改成你資料庫的照片即可！
    this.imagePath =
        'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
  }) : super(key: key);

  @override
  State<RolePlayIntroScreen> createState() => _RolePlayIntroScreenState();
}

class _RolePlayIntroScreenState extends State<RolePlayIntroScreen> {
  // 🌟 讓旁邊卡片「露出來」的魔法控制器！(viewportFraction: 0.75)
  final PageController _pageController = PageController(viewportFraction: 0.78);

  // 這是深綠色的主色調
  final Color _darkGreen = const Color(0xFF4A7A4D);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 避免圖片載入前閃白光
      body: Stack(
        children: [
          // ==========================================
          // 1. 最底層：使用者提供的照片 (填滿上半部)
          // ==========================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // 讓照片高度佔據螢幕的 55%，確保被綠色底板蓋住時還有足夠空間
            height: MediaQuery.of(context).size.height * 0.55,
            child: Image.network(widget.imagePath, fit: BoxFit.cover),
          ),

          // ==========================================
          // 2. 左上角：返回按鈕
          // ==========================================
          Positioned(
            top: 50, // 避開手機頂部的瀏海或狀態列
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                Navigator.pop(context); // 點擊返回上一頁
              },
            ),
          ),

          // ==========================================
          // 3. 前景層：綠色底板 + 滑動卡片 + 開始按鈕
          // ==========================================
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              // 綠色底板佔據螢幕下方 60%
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFBFE1C3), // 你設計圖的淺綠色
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // --- 灰色小把手 (Drag Handle) ---
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 中間的白色左右滑動卡片群 ---
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 3, // 假設有 3 張卡片
                      itemBuilder: (context, index) {
                        return _buildVocabCard();
                      },
                    ),
                  ),

                  // --- 底部的 Start Role-Play 按鈕 ---
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 40,
                      top: 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: 這裡放入點擊開始角色扮演的邏輯
                          print('開始角色扮演！');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _darkGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Start Role-Play',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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

  // --- 製造白色單字卡片的模具 ---
  Widget _buildVocabCard() {
    return Container(
      // margin 讓卡片之間有空隙，且不會貼到畫面邊緣
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8), // 產生懸浮陰影
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💡 順帶一提小知識：「お勘定」的平假名應該是「おかんじょう (o-kan-jou)」。
            // 「おんせん」是溫泉的意思喔！我幫你把發音修正了 😉
            const Text(
              'おかんじょう',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'お勘定',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '結帳',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 20),

            const Text(
              'すみません、',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text(
              'Excuse me,',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text(
              'お勘定をお願いします。',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text(
              'Can I have the bill please?',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

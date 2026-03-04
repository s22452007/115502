import 'package:flutter/material.dart';

class RolePlayIntroScreen extends StatelessWidget {
  const RolePlayIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 這裡使用你設計圖上的優雅綠色系
    const Color cardBgColor = Color(0xFFCCE4D4);
    const Color buttonColor = Color(0xFF4A7D54);
    const Color textColor = Color(0xFF2E4F36);

    return Scaffold(
      body: Stack(
        children: [
          // 1. 上半部：居酒屋背景圖片
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.4, // 圖片佔滿上半部
            child: Container(
              color: Colors.grey[800], // 如果沒有圖片，先用深灰色墊底
              child: const Center(
                child: Icon(Icons.restaurant, size: 80, color: Colors.white54),
              ),
              // 未來你有居酒屋照片時，可以換成下面這行：
              // child: Image.asset('assets/images/izakaya_bg.png', fit: BoxFit.cover),
            ),
          ),

          // 2. 下半部：綠色圓角卡片區域
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65, // 佔畫面高度 65%
              decoration: const BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // 頂部的小灰條 (Drag handle)
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. 中間的白色單字學習卡
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
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
                          // 單字區域
                          const Text(
                            'おかんじょう',
                            style: TextStyle(
                              fontSize: 16,
                              color: buttonColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'お勘定',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '結帳',
                            style: TextStyle(
                              fontSize: 20,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(
                              color: Colors.black12,
                              thickness: 1.5,
                            ),
                          ),

                          // 例句區域
                          const Text(
                            'すみません、',
                            style: TextStyle(
                              fontSize: 18,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Excuse me,',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'お勘定お願いします。',
                            style: TextStyle(
                              fontSize: 18,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Can I have the bill please?',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. 底部的 Start Role-Play 按鈕
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
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

          // 左上角返回按鈕
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

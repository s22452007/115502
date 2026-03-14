import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class SceneResultScreen extends StatefulWidget {
  final String imagePath;

  const SceneResultScreen({
    Key? key,
    // 預設的假照片
    this.imagePath =
        'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
  }) : super(key: key);

  @override
  State<SceneResultScreen> createState() => _SceneResultScreenState();
}

class _SceneResultScreenState extends State<SceneResultScreen> {
  // 🌟 1. 管理綠幕高度的魔法變數
  double _curtainHeight = 350.0; // 🌟 一開始的高度 (預設縮起來，露出內容)

  // 🌟 2. 設定綠幕高度的限制 (為了不讓它被拉到爆，或者縮到不見)
  final double _minCurtainHeight = 50.0; // 🌟 往下滑到底時，要留點綠邊和灰色小把手
  final double _maxCurtainHeight = 550.0; // 🌟 往上拉到滿時，要能完全蓋住卡片和按鈕

  final Color _darkGreen = const Color(0xFF4A7A4D);

  @override
  Widget build(BuildContext context) {
    // 🌟 3. 計算整個內容區域 (卡片 + 按鈕) 的總高度，這將是綠幕可拖拉的極限高度
    // 這個高度是靜止不動的內容的高度，由卡片和按鈕的設計決定
    double _totalContentHeight = 600.0; // 🌟 給一個足夠大的固定高度，確保能裝下所有內容

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ==========================================
          // 第 1 層：最底層：使用者照片 (填滿整個背景)
          // ==========================================
          Positioned.fill(
            child:
                (kIsWeb ||
                    widget.imagePath.startsWith('http') ||
                    widget.imagePath.startsWith('blob:'))
                ? Image.network(widget.imagePath, fit: BoxFit.cover)
                : Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),

          // ==========================================
          // 第 2 層：左上角：返回按鈕
          // ==========================================
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ==========================================
          // 第 3 層：前景層：🌟 靜止內容 + 可拖拉綠幕 🌟
          // ==========================================
          // 🌟 我們將內容和綠幕都放在一個吸附在底部的 Stack 裡
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: _totalContentHeight, // 🌟 整個底部的區域是靜止不動的，且高度固定
              child: Stack(
                children: [
                  // ------------------------------------------
                  // 3-A 層：下層：靜止內容 (卡片 + 按鈕)
                  // ------------------------------------------
                  // 🌟 這層是靜止不動的內容，綠幕會疊加在它上面
                  Positioned.fill(
                    child: Column(
                      children: [
                        const SizedBox(height: 50), // 🌟 這裡留出空間給灰色小把手
                        // 白色單字卡片
                        _buildVocabCard(),
                        // 底部的 Start Role-Play 按鈕
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RoleplayScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
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

                  // ------------------------------------------
                  // 3-B 層：上層：🌟 聰明可拖拉綠幕 🌟
                  // ------------------------------------------
                  // 🌟 我們將它疊加在內容上面。當它的高度增加時，它會從底部開始升起，蓋住下面的內容。
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      // 🌟 4. 手勢偵測：當手指滑動這個綠幕或灰色把手時...
                      onVerticalDragUpdate: (DragUpdateDetails details) {
                        setState(() {
                          // 🌟 5. 聰明計算法：因為這個綠幕吸附在底部，當高度增加時，它會向上升起。
                          // 當手指「向上滑」時，這意代表著，使用者想要把綠幕「拉起來」蓋住內容。
                          // 這時候，手指移動的方向 (details.delta.dy) 是「負值」。
                          // 為了讓高度「增加」以便向上升起，我們需要「減去」這個移動量。
                          _curtainHeight -= details.delta.dy;

                          // 🌟 6. 高度限制魔法：使用 clamp 將高度限制在我們預設的範圍內，不會滑爆。
                          _curtainHeight = _curtainHeight.clamp(
                            _minCurtainHeight,
                            _maxCurtainHeight,
                          );
                        });
                      },
                      child: Container(
                        height: _curtainHeight, // 🌟 使用魔法變數來控制高度
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
                            // 灰色小把手
                            Container(
                              width: 48,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
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

  // --- 白色單字卡片模具 (保持原樣，因為原本就修得很完美了) ---
  Widget _buildVocabCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
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
      ),
    );
  }
}

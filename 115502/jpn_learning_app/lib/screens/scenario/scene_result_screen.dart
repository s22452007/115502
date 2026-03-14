import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class SceneResultScreen extends StatefulWidget {
  final String imagePath;

  const SceneResultScreen({
    Key? key,
    this.imagePath =
        'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
  }) : super(key: key);

  @override
  State<SceneResultScreen> createState() => _SceneResultScreenState();
}

class _SceneResultScreenState extends State<SceneResultScreen> {
  // ❌ 已經把 _pageController 刪掉了，因為不左右滑了！
  final Color _darkGreen = const Color(0xFF4A7A4D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 最底層：使用者照片 (現在讓它填滿整個背景)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0, // 讓照片填滿，底部會被綠色抽屜蓋住
            child:
                (kIsWeb ||
                    widget.imagePath.startsWith('http') ||
                    widget.imagePath.startsWith('blob:'))
                ? Image.network(widget.imagePath, fit: BoxFit.cover)
                : Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),

          // 2. 返回按鈕
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. 前景層：🌟 超酷的可上下滑動抽屜 🌟
          DraggableScrollableSheet(
            initialChildSize: 0.45, // 一開始的比例 (佔螢幕 45%)，露出一半以上的照片
            minChildSize: 0.25, // 往下滑到底的比例 (佔螢幕 25%)，留一點點在下面讓你還能拉上來
            maxChildSize: 0.85, // 往上拉到最滿的比例 (佔螢幕 85%)
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFBFE1C3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                // 🌟 使用 ListView 綁定 scrollController，它才知道什麼時候要拖拉整個綠色區塊
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 12),
                    // 灰色小把手 (提示可以拖拉)
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 直接放入單字卡，拿掉 PageView 就不會左右滑動了！
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
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 製造白色單字卡片的模具 (保持原樣，因為原本就修得很完美了) ---
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

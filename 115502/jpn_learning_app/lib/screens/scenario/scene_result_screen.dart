import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class SceneResultScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic>? analysisData;

  const SceneResultScreen({
    Key? key,
    // 預設的居酒屋照片
    this.imagePath =
        'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    this.analysisData,
  }) : super(key: key);

  @override
  State<SceneResultScreen> createState() => _SceneResultScreenState();
}

class _SceneResultScreenState extends State<SceneResultScreen> {
  // 🌟 魔法變數：控制綠色捲簾的當前高度 (一開始預設 550)
  double _curtainHeight = 550.0;
  final Color _darkGreen = const Color(0xFF4A7A4D);

  @override
  Widget build(BuildContext context) {
    // 取得螢幕高度，用來設定捲簾可以拉到的最高極限
    final double maxCurtainHeight = MediaQuery.of(context).size.height * 0.85;
    // 捲簾縮到最底時的高度 (只露出灰色把手跟一點點綠邊)
    final double minCurtainHeight = 80.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ==========================================
          // 1. 最底層：使用者照片 (填滿整個背景)
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
          // 2. 左上角：返回按鈕
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
          // 3. 前景層：🌟 可上下拖拉的綠色捲簾 (裡面裝著白色卡片)
          // ==========================================
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              // 🌟 偵測手指上下滑動
              onVerticalDragUpdate: (details) {
                setState(() {
                  // 手指往上滑是負值，所以用減的讓高度增加
                  _curtainHeight -= details.delta.dy;
                  // 限制高度，不要讓它被拉到螢幕外面，也不要縮到不見
                  _curtainHeight = _curtainHeight.clamp(
                    minCurtainHeight,
                    maxCurtainHeight,
                  );
                });
              },
              child: Container(
                height: _curtainHeight, // 捲簾的高度會跟著手指變化
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFBFE1C3), // 淺綠色底
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                // 🌟 關鍵：用 SingleChildScrollView 包住內容，但不允許內部滾動！
                // 這樣當綠色框變矮時，白色卡片不會被擠壓變形，而是像被「遮住」一樣自然隱藏！
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(), // 禁止卡片自己滾動
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
                      const SizedBox(height: 20),

                      // 🌟 白色單字卡片就乖乖裝在綠色捲簾裡面！
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 白色單字卡片模具 ---
  Widget _buildVocabCard() {
    List<String> labels = [];
    if (widget.analysisData != null && widget.analysisData!['labels'] != null) {
      labels = List<String>.from(widget.analysisData!['labels']);
    }
    String mainLabel = labels.isNotEmpty ? labels.first : 'Object';
    String text = widget.analysisData?['text'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
      child: Column(
        children: [
          const Text(
            'Object Detected',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainLabel,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            labels.length > 1
                ? 'Other labels: ${labels.skip(1).take(3).join(', ')}'
                : 'No other objects',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          if (text.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 10),
            const Text(
              'Detected Text:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

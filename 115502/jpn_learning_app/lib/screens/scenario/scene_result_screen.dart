import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
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
  final Set<int> _collectedIds = {};

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
              child: Column(
                children: [
                  // 🌟 1. 將「上下滑動偵測」限定在最上面的把手區域
                  GestureDetector(
                    behavior: HitTestBehavior.opaque, // 確保空白處也能滑動
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
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 🌟 2. 卡片內容區放入 Expanded 讓他佔滿剩下的空間，並且可以獨立滾動
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(), // 允許卡片自己滾動！
                      child: Column(
                        children: [
                          // 動態渲染每一張單字卡片
                          _buildVocabList(),

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
                                      builder: (_) => const RoleplayScreen(
                                        topicTitle: '情境對話練習',
                                      ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 動態將 AI 回傳的字彙陣列轉換成美麗的實體單字卡 ---
  Widget _buildVocabList() {
    List<dynamic> vocabs = [];
    if (widget.analysisData != null && widget.analysisData!['vocabs'] != null) {
      vocabs = List<dynamic>.from(widget.analysisData!['vocabs']);
    }
    List<dynamic> sentences = [];
    if (widget.analysisData != null &&
        widget.analysisData!['sentences'] != null) {
      sentences = List<dynamic>.from(widget.analysisData!['sentences']);
    }

    if (vocabs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('未能辨識出任何單字', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: List.generate(vocabs.length, (index) {
        final vocab = vocabs[index];
        // 對應第 n 個單字的例句 (防呆，確保不會超出陣列)
        final sentence = index < sentences.length ? sentences[index] : null;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 上半部：假名、單字、(暫時禁用的)星星
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vocab['kana'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vocab['word'] ?? '',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (vocab['vocab_id'] == null) return;
                      final int? currentUserId = Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).userId;
                      if (currentUserId == null) return;

                      try {
                        final result = await ApiClient.collectVocab(
                          currentUserId,
                          vocab['vocab_id'],
                        );
                        if (result.containsKey('error')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['error']),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          setState(() {
                            _collectedIds.add(vocab['vocab_id']);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已更新圖鑑收藏時間 ⭐'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('發生錯誤: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: Icon(
                      _collectedIds.contains(vocab['vocab_id'])
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: _collectedIds.contains(vocab['vocab_id'])
                          ? Colors.amber
                          : Colors.grey.shade300,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
              ),
              // 下半部：詞彙說明
              const Text(
                '詞彙說明',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                vocab['meaning'] ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

              if (sentence != null) ...[
                const SizedBox(height: 16),
                // 鷹架式例句區塊
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.volume_up,
                        color: Colors.blueGrey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sentence['japanese'] ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: Color(0xFF444444),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sentence['chinese'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

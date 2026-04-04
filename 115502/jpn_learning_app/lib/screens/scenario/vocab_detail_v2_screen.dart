import 'package:flutter/material.dart';

class VocabDetailV2Screen extends StatelessWidget {
  final String kanji;
  final String kana;
  final String meaning;
  final String example;
  final String imageUrl;

  const VocabDetailV2Screen({
    Key? key,
    required this.kanji,
    required this.kana,
    required this.meaning,
    required this.example,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 🌟 頂部大照片區域 (支援網路圖片)
          SliverAppBar(
            expandedHeight: 320.0,
            pinned: true,
            backgroundColor: const Color(0xFF6AA86B), // 你的主題綠色
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                // 如果圖片載入失敗，顯示預設的灰色背景
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
          ),
          
          // 🌟 底部單字詳細資訊
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上半部：假名、日文漢字、收藏星星
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kana, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              kanji,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.star, color: Colors.amber, size: 36),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
                  ),
                  
                  // 下半部：詞彙說明
                  const Text(
                    '詞彙說明',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 8),
                  Text(meaning, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  
                  // 例句區塊
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.volume_up_rounded, color: Colors.blueGrey, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            example,
                            style: const TextStyle(fontSize: 16, color: Color(0xFF444444), height: 1.4),
                          ),
                        ),
                      ],
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
}
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

  final Color figmaPrimaryColor = const Color(0xFF6AA86B);
  final Color figmaTextColor = const Color(0xFF333333);
  final Color figmaSubTextColor = const Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 上半部圖片
          Positioned(
            top: 0, left: 0, right: 0, height: 350,
            child: Image.network(
              imageUrl, 
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
              ),
            ),
          ),
          // 2. 返回按鈕
          Positioned(
            top: 50, left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 3. 下方資訊卡
          Positioned(
            top: 310, left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kana, style: TextStyle(fontSize: 16, color: figmaSubTextColor)),
                            const SizedBox(height: 4),
                            Text(kanji, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: figmaTextColor)),
                          ],
                        ),
                        Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1, color: Colors.grey.shade200),
                    ),
                    Text('詞彙說明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: figmaTextColor)),
                    const SizedBox(height: 12),
                    Text(
                      '$meaning\n\n例句：\n$example',
                      style: TextStyle(fontSize: 16, height: 1.6, color: figmaSubTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
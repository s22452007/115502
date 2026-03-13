import 'package:flutter/material.dart';

class VocabDetailV2Screen extends StatelessWidget {
  const VocabDetailV2Screen({Key? key}) : super(key: key);

  final Color figmaPrimaryColor = const Color(0xFF6AA86B);
  final Color figmaTextColor = const Color(0xFF333333);
  final Color figmaSubTextColor = const Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 上半部大圖片
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            // 🌟 換成橫式高畫質大圖
            child: Image.network(
              'https://picsum.photos/800/600', 
              fit: BoxFit.cover, // 確保圖片完美覆蓋上方區域
              errorBuilder: (context, error, stackTrace) {
                // 🛡️ 防呆機制
                return Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                );
              },
            ),
          ),

          // 2. 返回按鈕
          Positioned(
            top: 50, 
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. 下半部資訊卡片 
          Positioned(
            top: 310, 
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
                ],
              ),
              // 🌟 確保文字再多也不會出現黃黑警告
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
                            Text(
                              'えき', 
                              style: TextStyle(fontSize: 16, color: figmaSubTextColor, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '駅', 
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: figmaTextColor),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.volume_up_rounded, color: figmaPrimaryColor, size: 32),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1, color: Colors.grey.shade200, thickness: 1),
                    ),

                    Text(
                      '詞彙說明',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: figmaTextColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '車站 (Station)。\n\n例句：\n新宿駅はどこですか？\n(請問新宿車站在哪裡？)',
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
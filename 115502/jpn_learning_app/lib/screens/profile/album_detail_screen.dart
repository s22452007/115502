import 'package:flutter/material.dart';
import 'vocab_detail_v2_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumTitle; 
  final List<String> vocabList;

  const AlbumDetailScreen({
    Key? key, 
    required this.albumTitle,
    required this.vocabList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(albumTitle, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: vocabList.isEmpty 
          ? const Center(child: Text('這個相簿目前是空的', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 20, childAspectRatio: 0.8,
              ),
              itemCount: vocabList.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // 🌟 這裡補上假資料，確保點擊一般相簿也不會報錯
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => VocabDetailV2Screen(
                        kanji: vocabList[index],
                        kana: '拼音',
                        meaning: '暫無解釋',
                        example: '暫無例句',
                        imageUrl: 'https://picsum.photos/seed/${vocabList[index]}/800/600',
                      ),
                    ));
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(vocabList[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
import 'package:flutter/material.dart';
import 'vocab_detail_v2_screen.dart'; // 🌟 點擊照片後進入單字卡

class AlbumDetailScreen extends StatelessWidget {
  final String albumTitle; 

  const AlbumDetailScreen({Key? key, required this.albumTitle}) : super(key: key);

  final Color figmaPrimaryColor = const Color(0xFF6AA86B);
  final Color figmaBgColor = const Color(0xFFF9F9F9);
  final Color figmaTextColor = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    // 📂 假資料：這個相簿裡面的單字照片
    final List<String> vocabList = ['ラーメン', '駅', '切符', '荷物', '出口'];

    return Scaffold(
      backgroundColor: figmaBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: figmaTextColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          albumTitle, // 動態顯示相簿名稱
          style: TextStyle(color: figmaTextColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,       
          crossAxisSpacing: 16,    
          mainAxisSpacing: 20,     
          childAspectRatio: 0.8,   
        ),
        itemCount: vocabList.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // 🌟 點擊照片後，進入最終的「單字詳細卡片」
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VocabDetailV2Screen()),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: figmaPrimaryColor.withOpacity(0.1),
                        child: Icon(Icons.photo_outlined, size: 36, color: figmaPrimaryColor), // 照片圖示
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vocabList[index], 
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: figmaTextColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
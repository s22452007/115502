import 'package:flutter/material.dart';
import 'vocab_detail_v2_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumTitle; 
  final List<String> vocabList; // 🌟 新增：接收上一頁傳來的清單

  const AlbumDetailScreen({
    Key? key, 
    required this.albumTitle,
    required this.vocabList,    // 🌟 標記為必傳參數
  }) : super(key: key);

  final Color figmaPrimaryColor = const Color(0xFF6AA86B);
  final Color figmaBgColor = const Color(0xFFF9F9F9);
  final Color figmaTextColor = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
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
          albumTitle, 
          style: TextStyle(color: figmaTextColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      // 🌟 如果清單是空的，就顯示空狀態畫面；否則顯示網格照片
      body: vocabList.isEmpty 
          ? _buildEmptyState() 
          : _buildPhotoGrid(context),
    );
  }

  // ==========================================
  // 📭 精美的空狀態畫面
  // ==========================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 空資料夾的圖示
          Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '這個相簿目前是空的',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '快去拍照分析，把單字收藏進來吧！',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 📸 有照片時顯示的網格畫面
  // ==========================================
  Widget _buildPhotoGrid(BuildContext context) {
    return GridView.builder(
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
                    // 🌟 這裡使用前面教您的 Image.asset 讀取真實照片
                    child: Image.asset(
                      'assets/images/test_small.jpg', 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey));
                      },
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
    );
  }
}
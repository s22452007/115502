import 'package:flutter/material.dart';
import 'album_detail_screen.dart'; // 🌟 引入相簿內容頁

class PhotoFolderV2Screen extends StatefulWidget {
  const PhotoFolderV2Screen({Key? key}) : super(key: key);

  @override
  State<PhotoFolderV2Screen> createState() => _PhotoFolderV2ScreenState();
}

class _PhotoFolderV2ScreenState extends State<PhotoFolderV2Screen> {
  // ==========================================
  // 🎨 Figma 設計稿精準色號
  // ==========================================
  final Color figmaPrimaryColor = const Color(0xFF6AA86B); 
  final Color figmaBgColor = const Color(0xFFF9F9F9);      
  final Color figmaTextColor = const Color(0xFF333333);    
  final Color figmaUnselectedColor = const Color(0xFF9E9E9E); 

  // 📂 假資料：收藏夾的名稱清單
  final List<String> folderNames = [
    '拉麵店單字',
    '車站實用句',
    '居酒屋會話',
    '動漫常出',
    '日常打招呼',
    '機場必備'
  ];

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
          '我的收藏夾', 
          style: TextStyle(color: figmaTextColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. 頂部搜尋欄
          _buildSearchBar(),
          
          // 2. 下方的收藏夾網格
          Expanded(
            child: _buildPhotoGrid(context),
          ),
        ],
      ),
    );
  }

  // 🔍 搜尋欄 UI
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), 
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), 
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: '搜尋單字或收藏夾...',
            hintStyle: TextStyle(color: figmaUnselectedColor, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: figmaUnselectedColor),
            border: InputBorder.none, 
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            print('搜尋內容: $value');
          },
        ),
      ),
    );
  }

  // 📁 收藏夾網格
  Widget _buildPhotoGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,       // 1排 3 個
        crossAxisSpacing: 16,    
        mainAxisSpacing: 20,     
        childAspectRatio: 0.8,   // 長方形以容納文字
      ),
      itemCount: folderNames.length + 1, 
      itemBuilder: (context, index) {
        if (index == folderNames.length) {
          return _buildAddFolderButton();
        }
        return _buildFolderCard(context, folderNames[index]);
      },
    );
  }

  // 📁 單個資料夾卡片
  Widget _buildFolderCard(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        // 🌟 點擊後跳轉到「相簿內容頁」，並把資料夾名稱傳過去
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlbumDetailScreen(albumTitle: title)),
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
                  child: Icon(Icons.photo_album_rounded, size: 36, color: figmaPrimaryColor), // 相簿圖示
                ),
              ),
            ),
          ),
          const SizedBox(height: 8), 
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1, 
            overflow: TextOverflow.ellipsis, 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: figmaTextColor),
          ),
        ],
      ),
    );
  }

  // ➕ 新增收藏夾按鈕
  Widget _buildAddFolderButton() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('準備新增收藏夾...')),
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
                border: Border.all(color: Colors.grey.shade300, width: 2), 
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, size: 40, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新增收藏夾',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: figmaUnselectedColor),
          ),
        ],
      ),
    );
  }
}
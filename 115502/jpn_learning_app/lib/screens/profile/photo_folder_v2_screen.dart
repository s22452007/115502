import 'package:flutter/material.dart';
import 'album_detail_screen.dart'; 

class PhotoFolderV2Screen extends StatefulWidget {
  const PhotoFolderV2Screen({Key? key}) : super(key: key);

  @override
  State<PhotoFolderV2Screen> createState() => _PhotoFolderV2ScreenState();
}

class _PhotoFolderV2ScreenState extends State<PhotoFolderV2Screen> {
  final Color figmaPrimaryColor = const Color(0xFF6AA86B); 
  final Color figmaBgColor = const Color(0xFFF9F9F9);      
  final Color figmaTextColor = const Color(0xFF333333);    
  final Color figmaUnselectedColor = const Color(0xFF9E9E9E); 

  // 🌟 新增：用來記錄使用者輸入的搜尋關鍵字
  String searchQuery = '';

  Map<String, List<String>> foldersData = {
    '拉麵店單字': ['ラーメン', '駅', '切符'],
    '車站實用句': ['電車', 'ホーム'],
    '居酒屋會話': ['ビール'],
    '動漫常出': ['魔法', '世界'],
    '日常打招呼': ['おはよう', 'こんにちは'],
    '機場必備': ['パスポート'],
  };

  void _showAddFolderDialog() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('新增收藏夾', style: TextStyle(fontWeight: FontWeight.bold, color: figmaTextColor)),
          content: TextField(
            controller: controller,
            autofocus: true, 
            decoration: InputDecoration(
              hintText: '請輸入收藏夾名稱...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: figmaPrimaryColor, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: figmaPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    foldersData[controller.text.trim()] = []; 
                  });
                  Navigator.pop(context); 
                }
              },
              child: const Text('建立', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

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
        title: Text('我的收藏夾', style: TextStyle(color: figmaTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildPhotoGrid(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), 
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
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
          // 🌟 當輸入框內容改變時，更新狀態，觸發畫面重新渲染
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context) {
    // 🌟 核心過濾邏輯：只挑選出符合搜尋條件的相簿
    final filteredFolderNames = foldersData.keys.where((folderName) {
      // 1. 檢查「相簿名稱」是否包含關鍵字
      final matchTitle = folderName.contains(searchQuery);
      
      // 2. 檢查「相簿內的單字」是否包含關鍵字
      final matchVocab = foldersData[folderName]!.any((vocab) => vocab.contains(searchQuery));

      // 只要名稱或裡面的單字其中一個符合，就顯示這個相簿
      return matchTitle || matchVocab;
    }).toList();

    // 🌟 判斷是否要顯示「新增按鈕」 (如果有輸入搜尋字詞就不顯示)
    final bool isSearching = searchQuery.isNotEmpty;
    final int itemCount = filteredFolderNames.length + (isSearching ? 0 : 1);

    // 🌟 如果搜尋找不到任何結果，顯示提示畫面
    if (isSearching && filteredFolderNames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('找不到相關的收藏夾或單字', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,       
        crossAxisSpacing: 16,    
        mainAxisSpacing: 20,     
        childAspectRatio: 0.8,   
      ),
      itemCount: itemCount, 
      itemBuilder: (context, index) {
        // 如果不是在搜尋狀態，且到了最後一個項目，就顯示新增按鈕
        if (!isSearching && index == filteredFolderNames.length) {
          return _buildAddFolderButton();
        }
        return _buildFolderCard(context, filteredFolderNames[index]);
      },
    );
  }

  Widget _buildFolderCard(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(
              albumTitle: title,
              vocabList: foldersData[title]!, 
            ),
          ),
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
                  child: Icon(Icons.photo_album_rounded, size: 36, color: figmaPrimaryColor), 
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

  Widget _buildAddFolderButton() {
    return GestureDetector(
      onTap: _showAddFolderDialog, 
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
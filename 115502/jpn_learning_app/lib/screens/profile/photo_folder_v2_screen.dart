import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'album_detail_screen.dart';

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

  // 動態資料變數
  bool _isLoading = true;
  List<dynamic> _folders = [];         // 存放「所有」資料夾的總表
  List<dynamic> _filteredFolders = []; // 存放「搜尋結果」的清單

  @override
  void initState() {
    super.initState();
    _fetchFavorites(); 
  }

  // 從後端抓取資料的方法
  Future<void> _fetchFavorites() async {
    final userId = context.read<UserProvider>().userId;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _folders = []; 
        _filteredFolders = []; 
      });
      return;
    }

    final result = await ApiClient.fetchUserFavorites(userId);
    
    if (result.containsKey('favorites')) {
      setState(() {
        _folders = result['favorites'];
        _filteredFolders = _folders; // 剛抓完資料時，顯示全部的資料夾
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 負責處理搜尋邏輯的魔法函數
  void _runSearch(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      results = _folders;
    } else {
      results = _folders.where((folder) =>
          folder['name'].toString().toLowerCase().contains(enteredKeyword.toLowerCase())
      ).toList();
    }

    setState(() {
      _filteredFolders = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<UserProvider>().userId == null;

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
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: figmaPrimaryColor))
                : isGuest
                    ? _buildGuestMessage()
                    : _buildPhotoGrid(context),
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
          // 綁定搜尋函數：每當使用者打字，就會觸發搜尋
          onChanged: (value) => _runSearch(value),
        ),
      ),
    );
  }

  Widget _buildGuestMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: figmaUnselectedColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            '登入後即可建立專屬的收藏夾喔！',
            style: TextStyle(fontSize: 16, color: figmaUnselectedColor),
          ),
        ],
      ),
    );
  }

  // 收藏夾網格
  Widget _buildPhotoGrid(BuildContext context) {
    // 處理搜尋不到結果的狀況
    if (_filteredFolders.isEmpty && _folders.isNotEmpty) {
      return Center(
        child: Text('找不到相關的收藏夾 🥲', style: TextStyle(color: figmaUnselectedColor, fontSize: 16)),
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
      // 現在總數是根據「搜尋結果(_filteredFolders)」的數量來決定
      itemCount: _filteredFolders.length + 1, 
      itemBuilder: (context, index) {
        // 如果是最後一個項目，顯示新增按鈕
        if (index == _filteredFolders.length) {
          return _buildAddFolderButton();
        }
        // 顯示搜尋結果裡面的資料夾
        final folderName = _filteredFolders[index]['name'];
        return _buildFolderCard(context, folderName);
      },
    );
  }

  // 單個資料夾卡片
  Widget _buildFolderCard(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlbumDetailScreen(albumTitle: title, vocabList: const [])),
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

  // ➕ 新增收藏夾按鈕
  Widget _buildAddFolderButton() {
    return GestureDetector(
      onTap: () {
        _showAddFolderDialog(); 
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

  // 彈出輸入框的對話框
  void _showAddFolderDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增收藏夾', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '請輸入資料夾名稱',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: figmaPrimaryColor, width: 2),
              ),
            ),
            autofocus: true, 
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context); 
                  await _createNewFolder(name); 
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: figmaPrimaryColor),
              child: const Text('建立', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 處理與後端連線的邏輯
  Future<void> _createNewFolder(String name) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _isLoading = true); 

    final result = await ApiClient.createFolder(userId, name);
    
    if (result.containsKey('error')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
        setState(() => _isLoading = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新增成功！')));
        _fetchFavorites(); 
      }
    }
  }
}
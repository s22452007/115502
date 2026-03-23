import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'album_detail_screen.dart';
// 🌟 引入單字卡畫面，讓預設相簿可以跳轉
import 'vocab_detail_v2_screen.dart'; 

class PhotoFolderV2Screen extends StatefulWidget {
  const PhotoFolderV2Screen({Key? key}) : super(key: key);

  @override
  State<PhotoFolderV2Screen> createState() => _PhotoFolderV2ScreenState();
}

class _PhotoFolderV2ScreenState extends State<PhotoFolderV2Screen> {
  // ==========================================
  // 🎨 Figma 設計稿精準色號 (配合一般相簿風格)
  // ==========================================
  final Color figmaPrimaryColor = const Color(0xFF6AA86B); // J-Lens 品牌綠
  final Color figmaBgColor = const Color(0xFFF9F9F9);      
  final Color figmaTextColor = const Color(0xFF333333);    
  final Color figmaUnselectedColor = const Color(0xFF9E9E9E); 

  bool _isLoading = true;
  List<dynamic> _folders = [];         
  List<dynamic> _filteredFolders = []; 

  // 🌟 定義預設相簿的資料結構
  final Map<String, dynamic> defaultFolder = {
    'id': 'default_01', 
    'name': '預設相簿 (基礎單字)', 
    'isDefault': true
  };

  @override
  void initState() {
    super.initState();
    _fetchFavorites(); 
  }

  Future<void> _fetchFavorites() async {
    final userId = context.read<UserProvider>().userId;

    // 🛡️ 保持專案原邏輯：訪客無法取得資料，會顯示鎖頭畫面
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final result = await ApiClient.fetchUserFavorites(userId);
    
    if (result.containsKey('favorites')) {
      setState(() {
        // 🌟 將預設相簿放在陣列的第一個位置
        _folders = [defaultFolder, ...result['favorites']];
        _filteredFolders = _folders; 
        _isLoading = false;
      });
    } else {
      setState(() {
        _folders = [defaultFolder]; // 就算抓失敗也保留預設相簿
        _filteredFolders = _folders;
        _isLoading = false;
      });
    }
  }

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
    // 監聽使用者狀態
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
      // 🌟 判斷：如果是訪客，顯示鎖頭畫面；否則顯示收藏夾內容
      body: isGuest 
          ? _buildGuestLockedView()
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: figmaPrimaryColor))
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
          onChanged: (value) => _runSearch(value),
        ),
      ),
    );
  }

  // 收藏夾網格
  Widget _buildPhotoGrid(BuildContext context) {
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
      itemCount: _filteredFolders.length + 1, // +1 是為了最後一個「新增」按鈕
      itemBuilder: (context, index) {
        if (index == _filteredFolders.length) {
          return _buildAddFolderButton();
        }
        
        final folder = _filteredFolders[index];
        // 🌟 判斷是不是預設相簿，給予不同的點擊事件，但外觀保持統一
        if (folder['isDefault'] == true) {
          return _buildDefaultFolderCard(context, folder['name']);
        } else {
          return _buildFolderCard(context, folder['name']);
        }
      },
    );
  }

  // 🌟 新版預設相簿卡片：外觀大小、顏色已與一般相簿統一，並改用專屬圖示
  Widget _buildDefaultFolderCard(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        // 跳轉到下方定義好的預設單字列表
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DefaultAlbumScreen()),
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
                  color: figmaPrimaryColor.withOpacity(0.1), // 統一的淺綠色背景
                  child: Icon(Icons.auto_awesome_rounded, size: 36, color: figmaPrimaryColor), // 專屬圖示，顏色統一
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: figmaTextColor), // 標題顏色統一
          ),
        ],
      ),
    );
  }

  // 一般資料夾卡片 (保留原本風格)
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

  // --- 🛡️ 保留原本專案的訪客鎖頭 UI ---
  Widget _buildGuestLockedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 80, color: figmaUnselectedColor),
          const SizedBox(height: 24),
          Text(
            '登入即可使用收藏夾功能',
            style: TextStyle(fontSize: 18, color: figmaTextColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            '保存你學過的重要單字，隨時複習',
            style: TextStyle(fontSize: 14, color: figmaUnselectedColor),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // 導向登入頁面
              Navigator.pushNamed(context, '/login'); 
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: figmaPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              '去登入',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🚀 預設相簿的單字列表畫面 (網格排列版)
// ==========================================
class DefaultAlbumScreen extends StatelessWidget {
  const DefaultAlbumScreen({Key? key}) : super(key: key);

  // 這裡保持原本的 5 個基本預設單字資料
  final List<Map<String, String>> defaultVocabs = const [
    {
      'kanji': '駅',
      'kana': 'えき',
      'meaning': '車站 (Station)',
      'example': '新宿駅はどこですか？\n(請問新宿車站在哪裡？)',
      'imageUrl': 'https://picsum.photos/seed/station/800/600',
    },
    {
      'kanji': '桜',
      'kana': 'さくら',
      'meaning': '櫻花 (Sakura)',
      'example': '春になると桜が咲きます。\n(一到春天櫻花就會開。)',
      'imageUrl': 'https://picsum.photos/seed/sakura/800/600',
    },
    {
      'kanji': '美味しい',
      'kana': 'おいしい',
      'meaning': '好吃的 (Delicious)',
      'example': 'このラーメンはとても美味しいです。\n(這碗拉麵非常美味。)',
      'imageUrl': 'https://picsum.photos/seed/delicious/800/600',
    },
    {
      'kanji': '友達',
      'kana': 'ともだち',
      'meaning': '朋友 (Friend)',
      'example': '週末は友達と遊びに行きます。\n(週末要和朋友出去玩。)',
      'imageUrl': 'https://picsum.photos/seed/friends/800/600',
    },
    {
      'kanji': '挨拶',
      'kana': 'あいさつ',
      'meaning': '打招呼 (Greeting)',
      'example': '元気よく挨拶をしましょう。\n(很有精神地打招呼吧。)',
      'imageUrl': 'https://picsum.photos/seed/greeting/800/600',
    },
  ];

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
        title: const Text(
          '預設相簿',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      // 🌟 將原本的 ListView 換成 GridView
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        // 設定網格的 Delegate：這裡使用 FixedCrossAxisCount 來決定一列顯示幾個
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,       // 🌟 一列顯示 3 個 (跟手機相簿類似)
          crossAxisSpacing: 12,    // 網格間的橫向間距
          mainAxisSpacing: 16,     // 網格間的縱向間距
          childAspectRatio: 0.8,   // 網格卡片的長寬比 (稍微高一點以容納文字)
        ),
        itemCount: defaultVocabs.length,
        itemBuilder: (context, index) {
          final vocab = defaultVocabs[index];
          
          return GestureDetector(
            onTap: () {
              // 🌟 點擊後跳轉到動態單字卡邏輯
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VocabDetailV2Screen(
                    kanji: vocab['kanji']!,
                    kana: vocab['kana']!,
                    meaning: vocab['meaning']!,
                    example: vocab['example']!,
                    imageUrl: vocab['imageUrl']!,
                  ),
                ),
              );
            },
            // 🌟 重新設計的網格卡片 UI (類似相簿)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 圖片部分 (網格的主體)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05), 
                          blurRadius: 4,
                          offset: const Offset(0, 2)
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        vocab['imageUrl']!,
                        fit: BoxFit.cover, // 🌟 確保圖片像手機相簿一樣填滿區域
                        errorBuilder: (ctx, err, stack) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey, size: 30),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8), 
                // 只保留漢字單字顯示在圖片下方
                Text(
                  vocab['kanji']!,
                  textAlign: TextAlign.center,
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, 
                  style: const TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333)
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
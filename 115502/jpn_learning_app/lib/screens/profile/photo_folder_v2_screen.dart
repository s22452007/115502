import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'album_detail_screen.dart';
import 'vocab_detail_v2_screen.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';

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

  bool _isLoading = true;
  String _searchKeyword = '';

  List<Map<String, dynamic>> _folders = [];

  // 🌟 搜尋結果分兩個陣列存放：符合的「相簿」與符合的「單字照片」
  List<Map<String, dynamic>> _filteredFolders = [];
  List<Map<String, dynamic>> _filteredVocabs = [];

  // 將預設相簿的單字直接整合在這裡，讓它也能被搜尋
  final Map<String, dynamic> defaultFolder = {
    'id': 'default_01',
    'name': '預設相簿 (基礎單字)',
    'isDefault': true,
    'vocabList': [
      {
        'kanji': '駅',
        'kana': 'えき',
        'meaning': '車站',
        'example': '新宿駅はどこですか？',
        'imageUrl':
            'https://images.unsplash.com/photo-1551641506-ee5bf4cb45f1?q=80&w=800&auto=format&fit=crop',
      },
      {
        'kanji': '桜',
        'kana': 'さくら',
        'meaning': '櫻花',
        'example': '桜が咲きます。',
        'imageUrl':
            'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=800&auto=format&fit=crop',
      },
      {
        'kanji': '美味しい',
        'kana': 'おいしい',
        'meaning': '好吃的',
        'example': 'とても美味しいです。',
        'imageUrl':
            'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?q=80&w=800&auto=format&fit=crop',
      },
      {
        'kanji': '友達',
        'kana': 'ともだち',
        'meaning': '朋友',
        'example': '友達と遊びます。',
        'imageUrl':
            'https://images.unsplash.com/photo-1529156069898-49953eb1f55f?q=80&w=800&auto=format&fit=crop',
      },
      {
        'kanji': '挨拶',
        'kana': 'あいさつ',
        'meaning': '打招呼',
        'example': '挨拶をしましょう。',
        'imageUrl':
            'https://images.unsplash.com/photo-1528605248644-14dd04022da1?q=80&w=800&auto=format&fit=crop',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _folders = [
        defaultFolder,
        // 🌟 初始化時給予空的 List<String> 存放單字
        {
          'id': '2',
          'name': '旅遊單字',
          'isDefault': false,
          'vocabList': <String>['切符', '空港'],
        },
        {
          'id': '3',
          'name': '餐廳用語',
          'isDefault': false,
          'vocabList': <String>[],
        },
      ];
      _filteredFolders = List.from(_folders);
      _isLoading = false;
    });
  }

  // 🌟 強大的「穿透式搜尋」邏輯
  void _runSearch(String enteredKeyword) {
    _searchKeyword = enteredKeyword.trim().toLowerCase();

    setState(() {
      if (_searchKeyword.isEmpty) {
        _filteredFolders = List.from(_folders);
        _filteredVocabs = [];
        return;
      }

      List<Map<String, dynamic>> matchedFolders = [];
      List<Map<String, dynamic>> matchedVocabs = [];

      for (var folder in _folders) {
        // 1. 搜相簿名稱
        if (folder['name'].toString().toLowerCase().contains(_searchKeyword)) {
          matchedFolders.add(folder);
        }

        // 2. 搜相簿裡面的單字
        final List<dynamic> vocabs = folder['vocabList'] ?? [];
        for (var vocab in vocabs) {
          String wordText = '';
          String kana = '假名(測試)';
          String meaning = '這是自訂單字的測試說明。';
          String example = 'テストの例文です。';
          String imageUrl = '';

          // 區分預設相簿(Map) 與 自訂相簿(String) 的資料結構
          if (vocab is Map) {
            wordText = vocab['kanji'] ?? '';
            kana = vocab['kana'] ?? kana;
            meaning = vocab['meaning'] ?? meaning;
            example = vocab['example'] ?? example;
            imageUrl = vocab['imageUrl'] ?? '';
          } else {
            wordText = vocab.toString();
            imageUrl = 'https://picsum.photos/seed/$wordText/800/600';
          }

          // 如果單字包含關鍵字，就把該單字轉成「照片卡」加入結果
          if (wordText.toLowerCase().contains(_searchKeyword)) {
            matchedVocabs.add({
              'kanji': wordText,
              'kana': kana,
              'meaning': meaning,
              'example': example,
              'imageUrl': imageUrl,
            });
          }
        }
      }

      _filteredFolders = matchedFolders;
      _filteredVocabs = matchedVocabs;
    });
  }

  void _showEditFolderDialog(Map<String, dynamic> folder) {
    final TextEditingController controller = TextEditingController(
      text: folder['name'],
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '編輯相簿名稱',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
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
              onPressed: () {
                setState(() => folder['name'] = controller.text.trim());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: figmaPrimaryColor,
              ),
              child: const Text('儲存', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteFolderDialog(Map<String, dynamic> folder) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '確認刪除',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text('確定要刪除「${folder['name']}」嗎？此動作無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _folders.removeWhere((f) => f['id'] == folder['id']);
                  _filteredFolders.removeWhere((f) => f['id'] == folder['id']);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('刪除', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddFolderDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '新增收藏夾',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
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
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _folders.add({
                      'id': DateTime.now().toString(),
                      'name': name,
                      'isDefault': false,
                      'vocabList': <String>[],
                    });
                    _runSearch(_searchKeyword); // 更新畫面
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: figmaPrimaryColor,
              ),
              child: const Text('建立', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
          style: TextStyle(
            color: figmaTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isGuest
          ? _buildGuestLockedView()
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: figmaPrimaryColor,
                          ),
                        )
                      : _buildMixedGrid(context),
                ),
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
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: '搜尋相簿名稱或單字...',
            hintStyle: TextStyle(color: figmaUnselectedColor, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: figmaUnselectedColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (value) => _runSearch(value),
        ),
      ),
    );
  }

  // 🌟 將「相簿」與搜到的「照片」混合顯示在同一個網格
  Widget _buildMixedGrid(BuildContext context) {
    if (_searchKeyword.isNotEmpty &&
        _filteredFolders.isEmpty &&
        _filteredVocabs.isEmpty) {
      return Center(
        child: Text(
          '找不到相關的相簿或單字 🥲',
          style: TextStyle(color: figmaUnselectedColor, fontSize: 16),
        ),
      );
    }

    List<Widget> gridItems = [];

    // 1. 放入符合的相簿
    for (var folder in _filteredFolders) {
      if (folder['isDefault'] == true) {
        gridItems.add(_buildDefaultFolderCard(context, folder));
      } else {
        gridItems.add(_buildFolderCard(context, folder));
      }
    }

    // 2. 放入搜到的單字照片
    for (var vocab in _filteredVocabs) {
      gridItems.add(_buildVocabCard(context, vocab));
    }

    // 3. 只有在沒搜尋時才顯示「新增按鈕」
    if (_searchKeyword.isEmpty) {
      gridItems.add(_buildAddFolderButton());
    }

    return GridView.count(
      padding: const EdgeInsets.all(16.0),
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 20,
      childAspectRatio: 0.8,
      children: gridItems,
    );
  }

  Widget _buildDefaultFolderCard(
    BuildContext context,
    Map<String, dynamic> folder,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DefaultAlbumScreen(defaultVocabs: folder['vocabList']),
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: figmaPrimaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 36,
                    color: figmaPrimaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            folder['name'],
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: figmaTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, Map<String, dynamic> folder) {
    return GestureDetector(
      onTap: () {
        // 🌟 1. 把舊的「純文字陣列」，轉換成升級版的「VocabItem 物件陣列」
        final List<String> oldVocabs = List<String>.from(
          folder['vocabList'] ?? [],
        );
        final List<VocabItem> newVocabItems = oldVocabs
            .map(
              (word) => VocabItem(
                word: word,
                kana: '尚未建立', // 預設值
                meaning: '自訂單字', // 預設值
                exampleSentence: '尚未建立例句', // 預設值
              ),
            )
            .toList();

        // 🌟 2. 把它包裝成 AlbumDetailScreen 現在唯一認識的 ScenarioItem 格式
        final currentScenario = ScenarioItem(
          title: folder['name'] ?? '未命名相簿',
          date: '自訂相簿',
          vocabularyList: newVocabItems,
        );

        // 🌟 3. 完美傳遞新鑰匙並跳轉！
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(scenario: currentScenario),
          ),
        ).then((_) {
          // 從相簿回來時，重新跑一次搜尋以便更新外面的縮圖或清單
          setState(() {
            _runSearch(_searchKeyword);
          });
        });
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: figmaPrimaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.photo_album_rounded,
                        size: 36,
                        color: figmaPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                folder['name'],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: figmaTextColor,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Colors.black54,
                ),
              ),
              onSelected: (value) {
                if (value == 'edit') _showEditFolderDialog(folder);
                if (value == 'delete') _showDeleteFolderDialog(folder);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('編輯名稱')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('刪除相簿', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 單字照片卡片 (供搜尋結果使用)
  Widget _buildVocabCard(BuildContext context, Map<String, dynamic> vocab) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VocabDetailV2Screen(
              kanji: vocab['kanji'],
              kana: vocab['kana'],
              meaning: vocab['meaning'],
              example: vocab['example'],
              imageUrl: vocab['imageUrl'],
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  vocab['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vocab['kanji'],
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFolderButton() {
    return GestureDetector(
      onTap: () {
        final isGuest = context.read<UserProvider>().userId == null;
        if (isGuest) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登入後即可建立專屬的收藏夾喔！')));
          return;
        }
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: figmaUnselectedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestLockedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 80,
            color: figmaUnselectedColor,
          ),
          const SizedBox(height: 24),
          Text(
            '登入即可使用收藏夾功能',
            style: TextStyle(
              fontSize: 18,
              color: figmaTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(backgroundColor: figmaPrimaryColor),
            child: const Text('去登入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// 🚀 預設相簿的單字列表畫面 (接收外部傳入的動態資料)
class DefaultAlbumScreen extends StatelessWidget {
  final List<dynamic> defaultVocabs;

  const DefaultAlbumScreen({Key? key, required this.defaultVocabs})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '預設相簿',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: defaultVocabs.length,
        itemBuilder: (context, index) {
          final vocab = defaultVocabs[index];
          return GestureDetector(
            onTap: () => Navigator.push(
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        vocab['imageUrl']!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vocab['kanji']!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
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

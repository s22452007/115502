import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class ScenarioDetailScreen extends StatelessWidget {
  final dynamic scene;

  const ScenarioDetailScreen({Key? key, required this.scene}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          // 使用 FutureBuilder 撈出該場景底下所有的單字清單
          FutureBuilder<List<dynamic>>(
            future: ApiClient.getSceneVocabs(scene['scene_id'], userId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator())),
                );
              }
              if (snapshot.hasError) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(50), child: Center(child: Text("載入單字失敗"))),
                );
              }

              final vocabs = snapshot.data ?? [];
              return _buildVocabularyList(vocabs);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 頂部大照片區域
  // ==========================================
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          scene['scene_name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        // 暫時用圖示代替，如果你資料庫有存 cover_image_url 可以改成 Image.network()
        background: Container(
          color: AppColors.primaryLighter,
          child: const Icon(Icons.camera_alt, size: 80, color: Colors.white),
        ),
      ),
    );
  }

  // ==========================================
  // 底部單字卡清單區域
  // ==========================================
  Widget _buildVocabularyList(List<dynamic> vocabs) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '在這個場景中識別出 ${vocabs.length} 個單字',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            // 動態產生單字卡
            ...vocabs.map((vocab) => _VocabCardWidget(vocab: vocab)).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 獨立單字卡元件 (StatefulWidget)
// ==========================================
class _VocabCardWidget extends StatefulWidget {
  final dynamic vocab;

  const _VocabCardWidget({Key? key, required this.vocab}) : super(key: key);

  @override
  State<_VocabCardWidget> createState() => _VocabCardWidgetState();
}

class _VocabCardWidgetState extends State<_VocabCardWidget> {
  bool _isLoading = true;
  bool _isStarred = false;
  String _exampleSentence = "例句載入中...";

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final userId = context.read<UserProvider>().userId;
    try {
      final detail = await ApiClient.getVocabDetail(widget.vocab['vocab_id'], userId!);
      if (mounted) {
        setState(() {
          _isStarred = detail['is_favorited'] ?? false;
          _exampleSentence = detail['example_sentence'] ?? '暫無提供例句';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exampleSentence = "載入失敗";
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================
  // 點擊星星後，彈出選擇資料夾的視窗
  // ==========================================
  void _toggleStar() {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    if (_isStarred) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('這個單字已經在你的收藏夾囉！')),
      );
      return;
    }

    // 彈出 BottomSheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 根據內容自動調整高度
              children: [
                const Text('請選擇要加入的單字本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Divider(height: 1),
                
                // 動態呼叫 API 撈取使用者的所有資料夾
                FutureBuilder<Map<String, dynamic>>(
                  future: ApiClient.fetchUserFavorites(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("載入資料夾失敗，請稍後再試"),
                      );
                    }

                    final data = snapshot.data ?? {};
                    final folders = data['favorites'] as List<dynamic>? ?? [];

                    // 限制最大高度，避免資料夾太多時破版
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final folder = folders[index];
                          final isDefault = folder['is_default'] == true;

                          return ListTile(
                            leading: Icon(
                              isDefault ? Icons.star : Icons.folder,
                              color: isDefault ? Colors.amber : const Color(0xFF8B6B9E),
                              size: 28,
                            ),
                            title: Text(folder['name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('已收錄 ${folder['count']} 個單字'),
                            onTap: () {
                              Navigator.pop(sheetContext); // 1. 先關閉彈出視窗
                              _executeCollection(userId, folder['id']); // 2. 執行收藏 API
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 真正發送 API 把單字塞入指定資料夾的函式
  Future<void> _executeCollection(int userId, int? folderId) async {
    final result = await ApiClient.collectVocab(userId, widget.vocab['vocab_id'], folderId: folderId);
    
    ScaffoldMessenger.of(context).clearSnackBars();
    
    if (result.containsKey('error')) {
      // 顯示後端回傳的錯誤 (例如: 已經收藏過囉)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
    } else {
      // 收藏成功，星星變黃色
      setState(() => _isStarred = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已成功加入單字本！⭐'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上半部：日文、假名、星星
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.vocab['kana'], style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      widget.vocab['word'],
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                  ],
                ),
              ),
              // 星星按鈕
              GestureDetector(
                onTap: _toggleStar,
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _isStarred ? Colors.amber : Colors.grey.shade300,
                      size: 40,
                    ),
              ),
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
          ),
          
          // 下半部：詞彙說明與例句
          const Text('詞彙說明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Text(widget.vocab['meaning'], style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 16),
          
          // 例句區塊
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volume_up_rounded, color: Colors.blueGrey, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _exampleSentence, 
                    style: const TextStyle(fontSize: 16, color: Color(0xFF444444), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
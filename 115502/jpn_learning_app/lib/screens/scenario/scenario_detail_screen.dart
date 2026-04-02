import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class ScenarioDetailScreen extends StatelessWidget {
  // 改為接收動態的 Map 資料，而不是寫死的 ScenarioItem
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
// 會自己抓取例句、記住按讚狀態的獨立單字卡元件
// ==========================================
class _VocabCardWidget extends StatefulWidget {
  final dynamic vocab; // 接收從 SceneVocabs 撈回來的基本單字資料

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

  // 單字卡一載入，就去後端問「我有沒有收藏這個字？」、「這個字的例句是什麼？」
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

  // 切換星星的邏輯
  Future<void> _toggleStar() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    if (_isStarred) {
      // 💡 溫馨提醒：因為你的後端 models 裡目前只有寫 /collect 的新增收藏，沒有取消
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目前系統版本暫不支援取消收藏喔！')));
      return;
    }

    // 發送收藏 API
    final success = await ApiClient.toggleFavorite(widget.vocab['vocab_id'], userId);
    if (success) {
      setState(() => _isStarred = true);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已加入收藏單字本！⭐'),
          duration: const Duration(seconds: 1),
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
                    _exampleSentence, // 動態顯示從後端撈回來的例句
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
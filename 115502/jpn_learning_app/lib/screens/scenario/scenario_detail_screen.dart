import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';

class ScenarioDetailScreen extends StatelessWidget {
  final ScenarioItem scenario;

  const ScenarioDetailScreen({Key? key, required this.scenario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          _buildVocabularyList(),
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
          scenario.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        background: scenario.image != null
            ? Image.asset(
                scenario.image!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primaryLighter,
                    child: const Icon(Icons.camera_alt, size: 80, color: Colors.white),
                  );
                },
              )
            : Container(
                color: AppColors.primaryLighter,
                child: const Icon(Icons.camera_alt, size: 80, color: Colors.white),
              ),
      ),
    );
  }

  // ==========================================
  // 底部單字卡清單區域
  // ==========================================
  Widget _buildVocabularyList() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '在這張照片中識別出 ${scenario.vocabularyList.length} 個單字',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            // 這裡改呼叫下方獨立出來的 Stateful 單字卡元件
            ...scenario.vocabularyList.map((vocab) => _VocabCardWidget(vocab: vocab)).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 會記住按讚狀態的獨立單字卡元件 (StatefulWidget)
// ==========================================
class _VocabCardWidget extends StatefulWidget {
  final VocabItem vocab;

  const _VocabCardWidget({Key? key, required this.vocab}) : super(key: key);

  @override
  State<_VocabCardWidget> createState() => _VocabCardWidgetState();
}

class _VocabCardWidgetState extends State<_VocabCardWidget> {
  bool _isStarred = false; // 預設未收藏 (灰色)

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
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
                    Text(
                      widget.vocab.kana,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.vocab.word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 讓星星可以點擊切換顏色與狀態！
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isStarred = !_isStarred; // 狀態反轉
                  });
                  
                  // 顯示提示訊息 (SnackBar)
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isStarred ? '已加入收藏單字本！⭐' : '已取消收藏'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Icon(
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
          const Text(
            '詞彙說明',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.vocab.meaning,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
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
                    widget.vocab.exampleSentence,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF444444),
                      height: 1.4,
                    ),
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
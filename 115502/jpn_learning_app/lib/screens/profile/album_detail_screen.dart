import 'package:flutter/material.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';

class AlbumDetailScreen extends StatelessWidget {
  final ScenarioItem scenario;

  const AlbumDetailScreen({Key? key, required this.scenario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 淺灰底色，讓白色單字卡更立體
      // 使用 CustomScrollView 做出「照片在頂部，往上滑會縮小」的高級質感
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          _buildVocabularyList(),
        ],
      ),
    );
  }

  // ==========================================
  // 頂部大照片區域 (會隨滾動縮小)
  // ==========================================
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320.0, // 照片的預設高度
      pinned: true, // 往上滑時，標題列會固定在最上方
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
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)], // 加上陰影避免字跟照片糊在一起
          ),
        ),
        // 照片背景處理：有照片就顯示，沒有就顯示相機 Icon
        background: scenario.image != null
            ? Image.asset(
                scenario.image!,
                fit: BoxFit.cover,
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
        // 這裡加上背景色，營造出「白色面板蓋在照片上」的層次感
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
            
            // 自動生成所有單字卡片
            ...scenario.vocabularyList.map((vocab) => _buildVocabCard(vocab)).toList(),
            
            const SizedBox(height: 40), // 底部留白，避免被導覽列遮擋
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 單一單字卡片的精美設計
  // ==========================================
  Widget _buildVocabCard(VocabItem vocab) {
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
                      vocab.kana,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vocab.word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.star, color: Colors.amber, size: 36), // 收藏星星
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
            vocab.meaning,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // 例句區塊 (帶淡色背景提升質感)
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
                    vocab.exampleSentence,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF444444),
                      height: 1.4, // 增加行高讓閱讀更舒適
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
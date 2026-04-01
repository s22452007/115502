import 'package:flutter/material.dart';

// 確保這兩個路徑正確指向你的檔案
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
          // --- 頂部：這張場景的「唯一大照片」 ---
          SliverAppBar(
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
              // 照片背景
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
          ),

          // --- 底部：這張照片裡識別出的「所有單字卡片」 ---
          SliverToBoxAdapter(
            child: Container(
              // 這裡加上圓角，讓它有一種「白色面板蓋在照片上」的感覺
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '在這張照片中識別出 ${scenario.vocabularyList.length} 個單字',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  
                  // 自動把這張照片裡的所有單字，變成一張張精美的卡片
                  ...scenario.vocabularyList.map((vocab) => _buildVocabCard(vocab)).toList(),
                  
                  const SizedBox(height: 40), // 底部留白
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 單字卡片的精美設計 (完美復刻你的圖二)
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
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          Text(
            vocab.meaning,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // 例句區塊 (帶一點淡色背景，質感升級)
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
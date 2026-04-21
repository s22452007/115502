import 'package:flutter/material.dart';

class SingleVocabDetailScreen extends StatefulWidget {
  final int vocabId;
  final String word;
  final String kana;
  final String meaning;

  const SingleVocabDetailScreen({
    Key? key,
    required this.vocabId,
    required this.word,
    required this.kana,
    required this.meaning,
  }) : super(key: key);

  @override
  State<SingleVocabDetailScreen> createState() => _SingleVocabDetailScreenState();
}

class _SingleVocabDetailScreenState extends State<SingleVocabDetailScreen> {
  static const Color primaryGreen = Color(0xFF6AA86B);
  static const Color textColor = Color(0xFF333333);
  static const Color subTextColor = Color(0xFF888888);
  static const Color bgLightGreen = Color(0xFFF4F8F5); 
  static const Color starColor = Color(0xFFFFC107);

  bool _isStarred = true; 

  void _toggleStar() {
    setState(() => _isStarred = !_isStarred);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isStarred ? '已加入收藏' : '已取消收藏')),
    );
  }

  void _playSound(String text) {
    // 播放發音
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在播放發音：$text')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4EF), // 換成 App 統一的淺灰背景，讓白色卡片浮出來
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 透明 AppBar 讓畫面更一體
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 將星星移到右上角，不佔用卡片空間
          IconButton(
            onPressed: _toggleStar,
            icon: Icon(
              _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isStarred ? starColor : Colors.grey.shade400,
              size: 32,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 頂部：假名標籤與單字 ---
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 精美的假名標籤
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.kana,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 主單字置中放大
                    Center(
                      child: Text(
                        widget.word,
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 分隔線
              Divider(color: Colors.grey.shade100, thickness: 2, height: 0),

              // --- 中間：中文解釋 ---
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: Colors.grey.shade400, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          '詞彙說明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.meaning,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // --- 底部：例句區塊 ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                decoration: const BoxDecoration(
                  color: bgLightGreen,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '實用例句',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSentenceCard('初階', 'この${widget.word}は美味しいです。', primaryGreen),
                    const SizedBox(height: 16),
                    _buildSentenceCard('中階', 'この${widget.word}屋は行列ができるほど有名だ。', const Color(0xFF5B9983)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 例句現在變成了獨立且帶有播放按鈕的精緻小卡！
  Widget _buildSentenceCard(String level, String sentence, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側：難度標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              level,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
            ),
          ),
          const SizedBox(width: 12),
          // 中間：例句
          Expanded(
            child: Text(
              sentence,
              style: const TextStyle(fontSize: 16, color: textColor, height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          // 右側：實體播放按鈕
          GestureDetector(
            onTap: () => _playSound(sentence),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
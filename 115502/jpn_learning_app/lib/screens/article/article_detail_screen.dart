import 'package:flutter/material.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({Key? key, required this.article}) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _showTranslation = false;
  bool _isRecording = false; // 預留給下一步的錄音狀態

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('閱讀練習', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標籤區
            Row(
              children: [
                _buildTag(widget.article.theme, AppColors.primary),
                const SizedBox(width: 8),
                _buildTag(widget.article.level, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            
            // 標題
            Text(
              widget.article.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 24),
            
            // 日文主內容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: Text(
                widget.article.content,
                style: const TextStyle(fontSize: 18, height: 1.8, color: Colors.black87, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 20),

            // 翻譯切換按鈕
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showTranslation = !_showTranslation;
                  });
                },
                icon: Icon(_showTranslation ? Icons.visibility_off : Icons.g_translate_rounded, color: AppColors.primary),
                label: Text(
                  _showTranslation ? '隱藏中文翻譯' : '查看中文翻譯', 
                  style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),

            // 中文翻譯 (點擊後才顯示)
            if (_showTranslation) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Text(
                  widget.article.translation,
                  style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF5A6A7E), fontWeight: FontWeight.w500),
                ),
              ),
            ],
            
            const SizedBox(height: 35),
            
            // AI 重點文法解析區塊
            _buildGrammarSection(),
            
            const SizedBox(height: 120), // 留空間給底部的懸浮錄音按鈕
          ],
        ),
      ),
      // 懸浮置中的錄音按鈕
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildRecordButton(),
    );
  }

  // 共用小標籤元件
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
    );
  }

  // 文法解析卡片產生器
  Widget _buildGrammarSection() {
    final grammarData = widget.article.grammarPoints;
    if (grammarData == null || !grammarData.containsKey('grammars')) return const SizedBox.shrink();

    final List grammars = grammarData['grammars'];
    if (grammars.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_circle, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('重點文法解析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
          ],
        ),
        const SizedBox(height: 16),
        ...grammars.map((g) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.15), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g['expression'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue)),
                const SizedBox(height: 8),
                Text(g['meaning'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.5)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Text('例：${g['example'] ?? ''}', style: TextStyle(fontSize: 14, color: Colors.blueGrey[600], fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // 炫酷的錄音按鈕
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: () {
        // TODO: 下一步，我們要接上實際的手機麥克風錄音套件
        setState(() {
          _isRecording = !_isRecording;
        });
        
        if (_isRecording) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔴 開始錄音...請對著麥克風朗讀文章！')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 錄音結束！(準備傳送給 AI 分析...)')));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: _isRecording ? 45 : 30, vertical: 16),
        decoration: BoxDecoration(
          color: _isRecording ? const Color(0xFFFF4B4B) : AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? const Color(0xFFFF4B4B) : AppColors.primary).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              _isRecording ? '結束錄音' : '按下開始朗讀',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}
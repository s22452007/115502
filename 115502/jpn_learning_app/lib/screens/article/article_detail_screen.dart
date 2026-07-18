import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🌟 引入 kIsWeb 來判斷是否為網頁版
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'article_result_screen.dart'; // 使用相對路徑避免紅線

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  const ArticleDetailScreen({Key? key, required this.article}) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _showTranslation = false;
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  @override
  void dispose() {
    _audioRecorder.dispose(); 
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 🛑 停止錄音
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
      });

      if (path != null) {
        final result = await ApiClient.evaluateArticleAudio(path, widget.article.content);
        
        if (!mounted) return;
        setState(() => _isAnalyzing = false);
        debugPrint("👉 AI 回傳結果: $result");

        if (result['status'] == 'success') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ArticleResultScreen(resultData: result)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失敗：${result['message'] ?? '未知錯誤'}')));
        }
      }
    } else {
      // 🎤 開始錄音 (在這裡觸發權限詢問)
      // 🌟 使用 record 套件專屬的 hasPermission()，完美支援網頁版！
      if (await _audioRecorder.hasPermission()) {
        String? filePath;
        
        // 🌟 網頁版沒有手機資料夾，我們必須跳過路徑獲取，否則會直接當機崩潰！
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          filePath = '${dir.path}/reading_test.m4a'; 
        }
        
        // 啟動錄音
        await _audioRecorder.start(
          const RecordConfig(), 
          path: filePath ?? '', // 網頁版留空，系統會自動分配虛擬空間
        );
        
        setState(() => _isRecording = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔴 開始錄音，請對麥克風朗讀！')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('必須允許麥克風權限才能錄音喔！')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('閱讀練習', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTag(widget.article.theme, AppColors.primary),
                const SizedBox(width: 8),
                _buildTag(widget.article.level, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.article.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
            const SizedBox(height: 24),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Text(widget.article.content, style: const TextStyle(fontSize: 18, height: 1.8, color: Colors.black87, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showTranslation = !_showTranslation),
                icon: Icon(_showTranslation ? Icons.visibility_off : Icons.g_translate_rounded, color: AppColors.primary),
                label: Text(_showTranslation ? '隱藏中文翻譯' : '查看中文翻譯', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_showTranslation) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(16)),
                child: Text(widget.article.translation, style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF5A6A7E))),
              ),
            ],
            const SizedBox(height: 35),
            _buildGrammarSection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildRecordButton(),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
    );
  }

  Widget _buildGrammarSection() {
    final grammarData = widget.article.grammarPoints;
    if (grammarData == null || !grammarData.containsKey('grammars')) return const SizedBox.shrink();
    final List grammars = grammarData['grammars'];
    if (grammars.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [Icon(Icons.lightbulb_circle, color: Colors.amber, size: 28), SizedBox(width: 8), Text('重點文法解析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50)))]),
        const SizedBox(height: 16),
        ...grammars.map((g) => Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g['expression'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue)),
              const SizedBox(height: 8),
              Text(g['meaning'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
              Text('例：${g['example'] ?? ''}', style: TextStyle(fontSize: 14, color: Colors.blueGrey[600], fontWeight: FontWeight.w600)),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildRecordButton() {
    if (_isAnalyzing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(30)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            SizedBox(width: 10),
            Text('AI 語音解析中...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: _isRecording ? 45 : 30, vertical: 16),
        decoration: BoxDecoration(
          color: _isRecording ? const Color(0xFFFF4B4B) : AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: (_isRecording ? const Color(0xFFFF4B4B) : AppColors.primary).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              _isRecording ? '結束錄音' : '按下開始朗讀',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
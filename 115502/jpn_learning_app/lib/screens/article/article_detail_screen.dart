import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'article_result_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  const ArticleDetailScreen({Key? key, required this.article}) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _showTranslation = false;
  bool _showFurigana = true; 
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // 📝 假設使用者 ID 為 8 (請依據實際登入狀態替換)
  final int currentUserId = 8; 

  List<dynamic> get _vocabularies {
    final data = widget.article.grammarPoints;
    if (data != null && data.containsKey('vocabularies')) {
      return data['vocabularies'] as List<dynamic>;
    }
    return [];
  }

  @override
  void dispose() {
    _audioRecorder.dispose(); 
    super.dispose();
  }

  // ====================================================
  // 🌟 1. 單字字典彈出視窗
  // ====================================================
  void _showDictionaryDialog(Map<String, dynamic> vocab) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('單字字典', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vocab['reading'] ?? '', style: const TextStyle(fontSize: 16, color: Color(0xFF8E9AAB))),
              Text(vocab['word'] ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
              const Divider(height: 24),
              const Text('中文解釋：', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(vocab['meaning'] ?? '', style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
              label: const Text('加入收藏', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context); // 關閉字典
                _showFolderSelectionDialog(vocab); // 打開選擇資料夾彈窗
              },
            ),
          ],
        );
      },
    );
  }

  // ====================================================
  // 🌟 2. 選擇資料夾彈出視窗 (呼叫你原本寫好的 fetchUserFavorites)
  // ====================================================
  void _showFolderSelectionDialog(Map<String, dynamic> vocab) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiClient.fetchUserFavorites(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!['favorites'] == null) {
              return AlertDialog(
                title: const Text('錯誤'),
                content: const Text('無法載入您的收藏夾資料。'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
              );
            }

            final folders = snapshot.data!['favorites'] as List<dynamic>;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('選擇要加入的收藏夾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length + 1, // 多 1 個用來放「新增」按鈕
                  itemBuilder: (context, index) {
                    // 最下方的新增資料夾按鈕
                    if (index == folders.length) {
                      return ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                        title: const Text('新建收藏夾', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context); 
                          _showCreateFolderDialog(vocab);
                        },
                      );
                    }
                    
                    // 現有的資料夾列表 (包含預設)
                    final folder = folders[index];
                    final bool isDefault = folder['is_default'] ?? false;
                    return ListTile(
                      leading: Icon(isDefault ? Icons.star_rounded : Icons.folder_rounded, color: Colors.amber, size: 28),
                      title: Text(folder['name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text('${folder['count'] ?? 0} 字', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        _executeCollection(vocab, folder['id']);
                      },
                    );
                  },
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey)))],
            );
          },
        );
      },
    );
  }

  // ====================================================
  // 🌟 3. 新增自訂資料夾視窗
  // ====================================================
  void _showCreateFolderDialog(Map<String, dynamic> vocab) {
    final TextEditingController _folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('新建收藏夾', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _folderController,
            decoration: InputDecoration(
              hintText: '輸入資料夾名稱',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final name = _folderController.text.trim();
                if (name.isNotEmpty) {
                  try {
                    // 呼叫你原本寫好的建立資料夾 API
                    final folderId = await ApiClient.createFolder(currentUserId, name); 
                    if (!mounted) return;
                    Navigator.pop(context);
                    _executeCollection(vocab, folderId); // 建立成功後，直接把單字塞進去！
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('建立失敗: $e')));
                  }
                }
              },
              child: const Text('建立並收藏', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ====================================================
  // 🌟 4. 執行收藏動作並顯示提示
  // ====================================================
  Future<void> _executeCollection(Map<String, dynamic> vocab, int? folderId) async {
    final result = await ApiClient.collectArticleVocab(
      currentUserId, 
      vocab['word'], 
      vocab['reading'], 
      vocab['meaning'],
      folderId: folderId // 🌟 將選擇的資料夾 ID 傳給後端
    );

    if (!mounted) return;
    
    bool isSuccess = result['status'] == 'success';
    String msg = result['error'] ?? result['message'] ?? '處理中...';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  // ===== 以下為錄音與畫面排版 (維持原樣) =====
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
      });

      if (path != null) {
        final result = await ApiClient.evaluateArticleAudio(path, widget.article.content);
        if (!mounted) return;
        setState(() => _isAnalyzing = false);

        if (result['status'] == 'success') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ArticleResultScreen(resultData: result)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失敗：${result['message'] ?? '未知錯誤'}')));
        }
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        String? filePath;
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          filePath = '${dir.path}/reading_test.m4a'; 
        }
        await _audioRecorder.start(const RecordConfig(), path: filePath ?? '');
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
              width: double.infinity, 
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('日文內文', style: TextStyle(fontSize: 14, color: Color(0xFF8E9AAB), fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Text('顯示假名', style: TextStyle(fontSize: 13, color: Color(0xFF8E9AAB), fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Switch(value: _showFurigana, activeColor: AppColors.primary, onChanged: (val) => setState(() => _showFurigana = val)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const SizedBox(height: 4),
                  
                  // 🌟 假名解析器維持完美對齊版本
                  FuriganaText(
                    text: widget.article.content,
                    showFurigana: _showFurigana,
                    vocabularies: _vocabularies,
                    onVocabTap: _showDictionaryDialog,
                    style: const TextStyle(fontSize: 18, height: 2.2, color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
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
            Text('AI 語音解析中...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            Text(_isRecording ? '結束錄音' : '按下開始朗讀', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🌟 互動字典版：精準基準線對齊、可點擊的假名解析器
// ==========================================
class FuriganaText extends StatelessWidget {
  final String text;
  final bool showFurigana;
  final TextStyle style;
  final List<dynamic> vocabularies;
  final Function(Map<String, dynamic>) onVocabTap;

  const FuriganaText({
    Key? key,
    required this.text,
    required this.showFurigana,
    required this.style,
    required this.vocabularies,
    required this.onVocabTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showFurigana) {
      String cleanText = text.replaceAll(RegExp(r'<rt>.*?</rt>', dotAll: true), '');
      cleanText = cleanText.replaceAll(RegExp(r'<[^>]*>'), ''); 
      return Text(cleanText, style: style);
    }

    List<InlineSpan> spans = [];
    final RegExp regExp = RegExp(r'<ruby>(.*?)<rt>(.*?)</rt></ruby>', dotAll: true);
    int lastMatchEnd = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: style));
      }

      final String kanji = match.group(1) ?? '';
      final String furigana = match.group(2) ?? '';

      Map<String, dynamic>? matchingVocab;
      try {
        matchingVocab = vocabularies.firstWhere((v) => v['word'] == kanji);
      } catch (e) {
        matchingVocab = null;
      }

      Widget columnContent = Column(
        mainAxisSize: MainAxisSize.min,
        verticalDirection: VerticalDirection.up, 
        children: [
          Text(
            kanji,
            style: style.copyWith(
              height: 1.0, 
              color: matchingVocab != null ? AppColors.primary : style.color,
              decoration: matchingVocab != null ? TextDecoration.underline : TextDecoration.none,
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
          const SizedBox(height: 2), 
          Text(
            furigana,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 18) * 0.52,
              color: const Color(0xFF718096),
              height: 1.0, 
            ),
          ),
        ],
      );

      Widget finalWidget = columnContent;
      if (matchingVocab != null) {
        finalWidget = Tooltip(
          message: '點擊查看字典',
          child: MouseRegion(
            cursor: SystemMouseCursors.click, 
            child: GestureDetector(
              onTap: () => onVocabTap(matchingVocab!),
              child: columnContent,
            ),
          ),
        );
      }

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: finalWidget,
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return RichText(text: TextSpan(children: spans, style: style));
  }
}
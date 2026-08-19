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

  // 📝 假設使用者 ID 為 8 (之後若串接 UserProvider 可在此修改)
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('單字字典', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(vocab['reading'] ?? '', style: const TextStyle(fontSize: 16, color: Color(0xFF8E9AAB))),
                const SizedBox(height: 4),
                Text(vocab['word'] ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                const Text('中文解釋', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(vocab['meaning'] ?? '', style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showFolderSelectionDialog(vocab);
                    },
                    child: const Text('加入收藏', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====================================================
  // 🌟 2. 選擇資料夾彈出視窗
  // ====================================================
  void _showFolderSelectionDialog(Map<String, dynamic> vocab) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiClient.fetchUserFavorites(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Dialog(
                elevation: 0,
                child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!['favorites'] == null) {
              return Dialog(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('錯誤', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      const Text('無法載入您的收藏夾資料。', style: TextStyle(color: Colors.black87)),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('關閉', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              );
            }

            final folders = snapshot.data!['favorites'] as List<dynamic>;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('選擇加入的收藏夾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.maxFinite,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: folders.length + 1,
                          itemBuilder: (context, index) {
                            if (index == folders.length) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                                ),
                                title: const Text('新建收藏夾', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                onTap: () {
                                  Navigator.pop(context); 
                                  _showCreateFolderDialog(vocab);
                                },
                              );
                            }
                            
                            final folder = folders[index];
                            final bool isDefault = folder['is_default'] ?? false;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: Icon(isDefault ? Icons.star_border : Icons.folder_outlined, color: const Color(0xFF64748B), size: 20),
                              ),
                              title: Text(folder['name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              trailing: Text('${folder['count'] ?? 0} 字', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              onTap: () {
                                Navigator.pop(context);
                                _executeCollection(vocab, folder['id']);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('新建收藏夾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                const SizedBox(height: 20),
                TextField(
                  controller: _folderController,
                  decoration: InputDecoration(
                    hintText: '輸入資料夾名稱',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: () => Navigator.pop(context), 
                        child: const Text('取消', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, 
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: () async {
                          final name = _folderController.text.trim();
                          if (name.isNotEmpty) {
                            try {
                              final folderId = await ApiClient.createFolder(currentUserId, name); 
                              if (!mounted) return;
                              Navigator.pop(context);
                              _executeCollection(vocab, folderId); 
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('建立失敗: $e'),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                        child: const Text('建立', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
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
      folderId: folderId 
    );

    if (!mounted) return;
    
    bool isSuccess = result['status'] == 'success';
    
    String msg = (result['error'] ?? result['message'] ?? '處理中...')
        .toString()
        .replaceAll('✅', '')
        .trim();
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0, 
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
        margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24), 
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      )
    );
  }

  // ====================================================
  // 🌟 5. 錄音、評分與成績結算邏輯
  // ====================================================
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      debugPrint('🎤 錄音結束，取得路徑：$path'); // 追蹤是否有成功拿到檔案

      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
      });

      if (path != null && path.isNotEmpty) {
        // 1. 呼叫語音評分 API
        final result = await ApiClient.evaluateArticleAudio(path, widget.article.content);
        if (!mounted) return;

        if (result['status'] == 'success') {
          // 🛡️ 防呆：確保分數是整數
          final int score = double.tryParse(result['score']?.toString() ?? '0')?.toInt() ?? 0;
          
          // 2. 🌟 呼叫成績結算與點數發放 API
          await _submitScoreAndShowResult(score, result);
        } else {
          setState(() => _isAnalyzing = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失敗：${result['message'] ?? '未知錯誤'}')));
        }
      } else {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ 無法取得錄音檔案，請確認麥克風權限或重試')));
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        String? filePath;
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          filePath = '${dir.path}/reading_test.m4a'; 
        }
        
        // 🌟 修復核心：Web 平台不能傳遞空字串當路徑，必須明確傳 null
        await _audioRecorder.start(
          const RecordConfig(), 
          path: kIsWeb ? '' : (filePath ?? ''),
        );
        
        setState(() => _isRecording = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔴 開始錄音，請對麥克風朗讀！')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('必須允許麥克風權限才能錄音喔！')));
      }
    }
  }

  // 🌟 處理成績結算與導航
  Future<void> _submitScoreAndShowResult(int score, Map<String, dynamic> evaluateResult) async {
    final submitResult = await ApiClient.submitArticleScore(currentUserId, widget.article.id, score);
    
    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    // 跳轉到結果報告頁面
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => ArticleResultScreen(resultData: evaluateResult))
    );

    // 從結果報告頁面返回後，顯示點數與成就動畫
    if (submitResult['status'] == 'success' && submitResult['is_new_record'] == true) {
      final pointsEarned = submitResult['points_earned'] ?? 0;
      final highestScore = submitResult['highest_score'] ?? score;
      _showRewardDialog(pointsEarned, highestScore);
    } else if (submitResult['status'] == 'success') {
      final pointsEarned = submitResult['points_earned'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('練習完成！獲得 $pointsEarned J-pts 獎勵。'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  // 🌟 破紀錄與獲得點數的動畫對話框
  void _showRewardDialog(int points, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 80),
                const SizedBox(height: 16),
                const Text(
                  '恭喜刷新最高分紀錄！', 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))
                ),
                const SizedBox(height: 8),
                Text(
                  '本次得分：$score 分',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '獲得 $points 點 J-pts',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('繼續努力', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
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
                  
                  // 🌟 假名解析器
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
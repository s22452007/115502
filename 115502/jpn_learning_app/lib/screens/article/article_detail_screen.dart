import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/helpers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'article_result_screen.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
// 通用的標音元件（這個檔案底下另有文章專用的 FuriganaText，用前綴區分）
import 'package:jpn_learning_app/widgets/common/furigana_text.dart' as common;

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  /// 從作業進來時帶作業 id，朗讀結算完會自動繳交作業。一般練習不用帶。
  final int? assignmentId;

  const ArticleDetailScreen({Key? key, required this.article, this.assignmentId}) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _showTranslation = false;
  bool _showFurigana = true; 
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // 原本這裡寫死 8，所有人的朗讀成績和點數都記到 8 號使用者身上
  int? get currentUserId => context.read<UserProvider>().userId; 

  List<dynamic> get _vocabularies {
    final data = widget.article.grammarPoints;
    if (data != null && data.containsKey('vocabularies')) {
      return data['vocabularies'] as List<dynamic>;
    }
    return [];
  }

  // 每日朗讀評分次數（免費版 1、Premium 5，教育版不限）。進畫面時向後端查，
  // 用完就在開始錄音「之前」擋下，不要錄完才告訴使用者不能評分。
  int? _readingLimit;
  int _readingUsed = 0;
  int _readingExtra = 0; // 商城加購的朗讀次數，每日次數用完後才會扣
  bool _readingUnlimited = false;

  int? get _readingLeft =>
      (_readingUnlimited || _readingLimit == null) ? null : (_readingLimit! - _readingUsed).clamp(0, _readingLimit!) + _readingExtra;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReadingQuota());
  }

  Future<void> _loadReadingQuota() async {
    final uid = currentUserId;
    if (uid == null) return;
    final res = await ApiClient.getUsageStatus(uid);
    if (!mounted || res.containsKey('error')) return;
    setState(() {
      _readingUnlimited = res['unlimited'] == true;
      _readingLimit = (res['reading_daily_limit'] as num?)?.toInt();
      _readingUsed = (res['reading_count_today'] as num?)?.toInt() ?? 0;
      _readingExtra = (res['reading_extra_count'] as num?)?.toInt() ?? 0;
    });
  }

  /// 今天的朗讀評分次數用完了：說明並提供升級入口（Premium 每天 5 次）
  void _showReadingQuotaDialog([String? message]) {
    final isPremium = context.read<UserProvider>().isPremium;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('今日朗讀次數已用完', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          message ??
              (isPremium
                  ? '今天的 ${_readingLimit ?? 5} 次朗讀評分已經用完了，明天再來挑戰吧！\n也可以到商城花 20 點加購 1 次。'
                  : '免費版每天可以朗讀評分 ${_readingLimit ?? 1} 次，明天再來挑戰吧！\n升級 Premium 每天可以朗讀 5 次，也可以到商城花 20 點加購 1 次。'),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了', style: TextStyle(color: Colors.grey))),
          if (!isPremium)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreDashboardScreen()));
              },
              child: const Text('查看 Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  /// 文章裡第一句含有這個字的句子（去掉讀音標記），找不到回傳 null
  String? _findArticleSentence(String word) {
    if (word.isEmpty) return null;
    final sentences = widget.article.content.split(RegExp(r'(?<=[。！？!?\n])'));
    for (final raw in sentences) {
      final plain = raw
          .replaceAll(RegExp(r'<rt>.*?</rt>', dotAll: true), '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (plain.contains(word)) return plain;
    }
    return null;
  }

  /// 文章原句：把查的那個字標成綠色
  Widget _highlightedSentence(String sentence, String word) {
    final parts = sentence.split(word);
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: word,
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
        ));
      }
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
        children: spans,
      ),
    );
  }

  Widget _dictSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
    );
  }

  // ====================================================
  // 🌟 1. 單字字典彈出視窗
  //    讀音、單字、中文解釋，加上：
  //      - 文章原句：這篇文章裡用到這個字的句子（不用 AI，馬上有）
  //      - 例句：字庫裡已經有這個字的話，顯示初級例句與翻譯
  //    已經收藏過就不再顯示「加入單字本」按鈕
  // ====================================================
  void _showDictionaryDialog(Map<String, dynamic> vocab) {
    final word = (vocab['word'] ?? '').toString();
    final articleSentence = _findArticleSentence(word);
    final lookup = currentUserId == null
        ? Future.value(<String, dynamic>{'found': false})
        : ApiClient.lookupVocab(currentUserId!, word);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: lookup,
                builder: (context, snapshot) {
                  final info = snapshot.data ?? const {};
                  final loading = snapshot.connectionState == ConnectionState.waiting;
                  final example = (info['sentence'] ?? '').toString();
                  final exampleZh = (info['translation'] ?? '').toString();
                  final favorited = info['is_favorited'] == true;

                  return Column(
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
                      Text(word, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _dictSectionLabel('中文解釋'),
                      Text(vocab['meaning'] ?? '', style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),

                      if (articleSentence != null) ...[
                        _dictSectionLabel('文章原句'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                          child: _highlightedSentence(articleSentence, word),
                        ),
                      ],

                      if (example.isNotEmpty) ...[
                        _dictSectionLabel('例句'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              common.FuriganaText(text: example, fontSize: 16, textColor: Colors.black87),
                              if (exampleZh.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(exampleZh, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      // 已收藏：顯示收在哪個單字本，可以取消收藏或移到其他單字本；還沒收藏：加入單字本
                      if (favorited) ...[
                        Row(
                          children: [
                            const Icon(Icons.bookmark_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('已收藏在「${info['folder_name'] ?? '預設單字本'}」',
                                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(color: AppColors.error.withOpacity(0.6)),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _removeFromWordBook(info, word);
                                },
                                child: const Text('取消收藏', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showMoveWordBookDialog(info, word);
                                },
                                child: const Text('移到其他單字本', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: const Color(0xFFE2E8F0),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: loading
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _showFolderSelectionDialog(vocab);
                                  },
                            child: const Text('加入單字本',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 從字典取消收藏
  Future<void> _removeFromWordBook(Map<String, dynamic> info, String word) async {
    final vocabId = (info['vocab_id'] as num?)?.toInt();
    if (currentUserId == null || vocabId == null) return;
    final ok = await ApiClient.removeFavorite(vocabId, currentUserId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已取消收藏「$word」' : '取消收藏失敗，請稍後再試')),
    );
  }

  /// 從字典把已收藏的字移到另一個單字本
  void _showMoveWordBookDialog(Map<String, dynamic> info, String word) {
    final userVocabId = (info['user_vocab_id'] as num?)?.toInt();
    if (currentUserId == null || userVocabId == null) return;
    final currentFolderId = info['folder_id'];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: FutureBuilder<Map<String, dynamic>>(
            future: ApiClient.fetchUserFavorites(currentUserId!),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
              }
              final folders = ((snapshot.data?['favorites'] as List?) ?? [])
                  .where((f) => f['id'] != currentFolderId)
                  .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('要把「$word」移到哪個單字本？', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 12),
                  if (folders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('目前沒有其他單字本，可以先在「加入單字本」時新建一個。', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                      child: ListView(
                        shrinkWrap: true,
                        children: folders.map((f) {
                          final isDefault = f['is_default'] == true;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(isDefault ? Icons.star_rounded : Icons.folder_rounded,
                                color: isDefault ? Colors.amber.shade600 : AppColors.primary),
                            title: Text(f['name'] ?? '未命名', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${f['count'] ?? 0} 個單字'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final res = await ApiClient.moveVocab(userVocabId, targetFolderId: f['id']);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(res['error'] != null ? res['error'].toString() : '已把「$word」移到「${f['name']}」'),
                              ));
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ====================================================
  // 🌟 2. 選擇資料夾彈出視窗
  // ====================================================
  void _showFolderSelectionDialog(Map<String, dynamic> vocab) {
    // 收藏單字要綁定帳號：沒登入就先提示。通過這裡之後，底下的 currentUserId! 都安全
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能收藏單字')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiClient.fetchUserFavorites(currentUserId!),
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
                              final folderId = await ApiClient.createFolder(currentUserId!, name); 
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
    final userId = currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能收藏單字')));
      return;
    }
    final result = await ApiClient.collectArticleVocab(
      userId, 
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
        final result = await ApiClient.evaluateArticleAudio(
          path,
          widget.article.content,
          userId: currentUserId,
          articleId: widget.article.id,
        );
        if (!mounted) return;

        if (result['status'] == 'quota_exceeded') {
          // 後端判定今天的次數已用完（例如在別台裝置用掉了）
          setState(() {
            _isAnalyzing = false;
            if (_readingLimit != null) _readingUsed = _readingLimit!;
            _readingExtra = 0;
          });
          _showReadingQuotaDialog(result['message']?.toString());
          return;
        }

        if (result['status'] == 'success') {
          setState(() {
            if (result['used_extra'] == true && _readingExtra > 0) _readingExtra--;
            _readingUsed++;
          });
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
      // 次數用完就不讓開始錄音，免得錄完才被擋
      if (_readingLeft == 0) {
        _showReadingQuotaDialog();
        return;
      }
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
    final userId = currentUserId;
    final evaluationId = (evaluateResult['evaluation_id'] as num?)?.toInt();

    // 沒登入、或後端沒存到評分（拿不到 evaluation_id）就無法結算成績：
    // 只顯示這次的朗讀報告，不發點數、也不算作業。
    final Map<String, dynamic> submitResult = (userId == null || evaluationId == null)
        ? {'status': 'skipped'}
        : await ApiClient.submitArticleScore(
            userId,
            widget.article.id,
            evaluationId,
            assignmentId: widget.assignmentId,
          );
    
    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    // 跳轉到結果報告頁面
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => ArticleResultScreen(resultData: evaluateResult))
    );

    // 從作業進來的：先告訴學生這次有沒有交到作業
    final assignmentResult = (submitResult['assignment_result'] as Map?)?.cast<String, dynamic>();
    if (assignmentResult != null && mounted) {
      final submitted = assignmentResult['submitted'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submitted
              ? '已繳交作業！'
              : '尚未交到作業：${assignmentResult['error'] ?? '請再試一次'}'),
          backgroundColor: submitted ? const Color(0xFF10B981) : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

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
                _buildTag(AppHelpers.getDifficultyLabel(widget.article.level), Colors.orange),
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
                  // 說明綠色字的用途（原本沒有任何提示，看不出可以點）
                  if (_vocabularies.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_rounded, size: 15, color: AppColors.primary),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text('點擊綠色的字，可以查看解釋並加入單字本',
                                style: TextStyle(fontSize: 12, color: AppColors.textSubtle)),
                          ),
                        ],
                      ),
                    ),
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

    final left = _readingLeft;
    final button = GestureDetector(
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

    // 教育版不限次數、或還沒查到次數時，只顯示按鈕
    if (left == null || _isRecording) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: left > 0 ? Colors.white : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Text(
            left > 0 ? '今日剩餘 $left 次朗讀評分' : '今日朗讀評分次數已用完',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: left > 0 ? AppColors.primary : const Color(0xFFD32F2F),
            ),
          ),
        ),
        button,
      ],
    );
  }
}

// ==========================================
// 🌟 互動字典版：精準基準線對齊、可點擊的假名解析器
// 綠色虛線底線的字是這篇文章要學的單字，點一下打開字典、可以加入單字本。
//   - 關掉假名時也保留綠色標記與點擊（原本關掉假名就整段變純文字，綠色字跟著消失）
//   - 沒有讀音標記的單字（例如片假名「パン」「コーヒー」）也會標綠色
//   - 讀音比漢字寬時（「私」上的「わたし」）可以延伸到旁邊沒有讀音的字上方，漢字後面不會空一格
// ==========================================
class _ArticleToken {
  final String text;
  final String? furigana; // null＝沒有讀音（或關掉假名）
  final Map<String, dynamic>? vocab; // 不是 null＝要學的單字
  const _ArticleToken(this.text, {this.furigana, this.vocab});
  bool get hasRuby => furigana != null && furigana!.isNotEmpty;
}

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
    final tokens = _tokenize();
    final rubyHeight = MediaQuery.textScalerOf(context).scale((style.fontSize ?? 18) * 0.52);

    bool freeAt(int i) => i >= 0 && i < tokens.length && !tokens[i].hasRuby;

    final spans = <InlineSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final baseStyle = t.vocab != null ? _vocabStyle : style;
      if (!t.hasRuby && t.vocab == null) {
        spans.add(TextSpan(text: t.text, style: style));
        continue;
      }
      Widget child = t.hasRuby
          ? _rubyColumn(t.text, t.furigana!, baseStyle, rubyHeight, leftFree: freeAt(i - 1), rightFree: freeAt(i + 1))
          : Text(t.text, style: baseStyle.copyWith(height: 1.0));
      if (t.vocab != null) {
        child = Tooltip(
          message: '點擊查看字典',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(onTap: () => onVocabTap(t.vocab!), child: child),
          ),
        );
      }
      spans.add(WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: child));
    }
    return RichText(text: TextSpan(children: spans, style: style));
  }

  TextStyle get _vocabStyle => style.copyWith(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: AppColors.primary,
      );

  /// 把文章拆成一段一段：<ruby> 標記的字、要學的單字、一般文字
  List<_ArticleToken> _tokenize() {
    final Map<String, Map<String, dynamic>> vocabByWord = {};
    for (final v in vocabularies) {
      if (v is Map && (v['word'] ?? '').toString().isNotEmpty) {
        vocabByWord[v['word'].toString()] = Map<String, dynamic>.from(v);
      }
    }
    // 一般文字裡要找出來標綠色的單字：長的先比對；全平假名的短字容易誤判（例如助詞），不從一般文字裡找
    final plainWords = vocabByWord.keys.where((w) => !RegExp(r'^[぀-ゟ]{1,2}$').hasMatch(w)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final wordPattern = plainWords.isEmpty ? null : RegExp(plainWords.map(RegExp.escape).join('|'));

    final tokens = <_ArticleToken>[];
    void addPlain(String s) {
      s = s.replaceAll(RegExp(r'<[^>]*>'), '');
      if (s.isEmpty) return;
      int last = 0;
      if (wordPattern != null) {
        for (final m in wordPattern.allMatches(s)) {
          if (m.start > last) tokens.add(_ArticleToken(s.substring(last, m.start)));
          tokens.add(_ArticleToken(m.group(0)!, vocab: vocabByWord[m.group(0)!]));
          last = m.end;
        }
      }
      if (last < s.length) tokens.add(_ArticleToken(s.substring(last)));
    }

    final rubyExp = RegExp(r'<ruby>(.*?)<rt>(.*?)</rt></ruby>', dotAll: true);
    int lastEnd = 0;
    for (final m in rubyExp.allMatches(text)) {
      addPlain(text.substring(lastEnd, m.start));
      final kanji = m.group(1) ?? '';
      tokens.add(_ArticleToken(kanji, furigana: showFurigana ? m.group(2) : null, vocab: vocabByWord[kanji]));
      lastEnd = m.end;
    }
    addPlain(text.substring(lastEnd));
    return tokens;
  }

  /// 讀音在上、漢字在下；verticalDirection.up 讓漢字當第一個子元件，基準線才會跟旁邊的字對齊。
  /// 讀音包在寬度 0 的盒子裡、用 OverflowBox 畫出來，整格寬度只看漢字；
  /// 只有兩邊都緊接著有讀音的字時，才照舊用讀音撐開，避免讀音互相重疊。
  Widget _rubyColumn(String kanji, String furigana, TextStyle baseStyle, double rubyHeight,
      {required bool leftFree, required bool rightFree}) {
    final rubyStyle = style.copyWith(
      fontSize: (style.fontSize ?? 18) * 0.52,
      color: const Color(0xFF718096),
      height: 1.0,
      decoration: TextDecoration.none,
    );
    final base = Text(kanji, style: baseStyle.copyWith(height: 1.0));
    final ruby = Text(furigana, style: rubyStyle, softWrap: false, maxLines: 1);

    if (!leftFree && !rightFree) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        verticalDirection: VerticalDirection.up,
        children: [base, const SizedBox(height: 2), ruby],
      );
    }

    // 假名與漢字幾乎等寬，用字數估讀音會不會比漢字寬（讀音字級是 0.52 倍）
    final rubyWider = furigana.length * 0.52 > kanji.length;
    CrossAxisAlignment cross = CrossAxisAlignment.center;
    Alignment align = Alignment.center;
    if (rubyWider && !(leftFree && rightFree)) {
      if (rightFree) {
        cross = CrossAxisAlignment.start; // 句首或左邊緊接著有讀音：只往右延伸
        align = Alignment.centerLeft;
      } else {
        cross = CrossAxisAlignment.end; // 只往左延伸
        align = Alignment.centerRight;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      verticalDirection: VerticalDirection.up,
      crossAxisAlignment: cross,
      children: [
        base,
        const SizedBox(height: 2),
        SizedBox(
          width: 0,
          height: rubyHeight,
          child: OverflowBox(maxWidth: double.infinity, alignment: align, child: ruby),
        ),
      ],
    );
  }
}

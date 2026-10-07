import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
// 匯入剛剛抽出去的單字卡元件
import 'package:jpn_learning_app/widgets/scenario/vocab_card.dart';
import 'package:jpn_learning_app/screens/scenario/make_sentence_screen.dart';
import 'package:jpn_learning_app/screens/scenario/grammar_tip_screen.dart';

class ScenarioDetailScreen extends StatefulWidget {
  final dynamic scene;

  const ScenarioDetailScreen({Key? key, required this.scene}) : super(key: key);

  @override
  State<ScenarioDetailScreen> createState() => _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends State<ScenarioDetailScreen> {
  late final Future<List<dynamic>> _vocabsFuture;
  /// 用這張照片練習造句的紀錄；null＝載入中
  List<Map<String, dynamic>>? _records;
  bool _recordsFailed = false;
  bool _showAllRecords = false;

  int? get _photoId => (widget.scene['photo_id'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    final userId = context.read<UserProvider>().userId!;
    _vocabsFuture = ApiClient.getVocabsByPhoto(widget.scene['image_path'], userId);
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || _photoId == null) {
      setState(() => _records = []);
      return;
    }
    try {
      final list = await ApiClient.getPhotoSentences(userId, _photoId!);
      if (!mounted) return;
      setState(() {
        _records = list;
        _recordsFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = [];
        _recordsFailed = true;
      });
    }
  }

  /// 用這張照片的單字再造一句，回來後重新整理紀錄
  Future<void> _practice(List<dynamic> vocabs) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MakeSentenceScreen(
          imagePath: widget.scene['image_path'] ?? '',
          vocabs: vocabs.map((v) => Map<String, dynamic>.from(v as Map)).toList(),
          contextDescription: widget.scene['context_description'],
          photoId: _photoId,
          showSkipButton: false,
        ),
      ),
    );
    if (mounted) _loadRecords();
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    int photoId,
    String currentName,
  ) async {
    final TextEditingController titleController = TextEditingController(
      text: currentName,
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改照片名稱'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '照片名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != currentName) {
                await ApiClient.renamePhoto(photoId, newTitle);
                if (mounted) {
                  setState(() {
                    widget.scene['scene_name'] = newTitle;
                  });
                }
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('確認修改', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPageTemplate(
      title: '情境詳情',
      hideAppBar: true,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          FutureBuilder<List<dynamic>>(
            future: _vocabsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: Text("載入單字失敗")),
                  ),
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

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color.fromARGB(255, 0, 0, 0)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.scene['photo_id'] != null)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: '修改這張照片的名稱',
            onPressed: () {
              _showRenameDialog(
                context,
                widget.scene['photo_id'],
                widget.scene['scene_name'],
              );
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.scene['scene_name'], 
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        background: widget.scene['image_path'] != null
            ? Image.network(
                widget.scene['image_path'].startsWith('http')
                    ? widget.scene['image_path']
                    : '${ApiClient.baseUrl.replaceAll('/api', '')}/static/photos/${widget.scene['image_path'].split('/').last}',
                fit: BoxFit.cover, 
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primaryLighter,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white),
                      SizedBox(height: 8),
                      Text('照片已遺失',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            : Container(
                color: AppColors.primaryLighter,
                child: const Icon(Icons.camera_alt, size: 80, color: Colors.white),
              ),
      ),
    );
  }

  /// 顯示拍照當下輸入的情境原文（沒填就不佔版面）
  Widget _buildContextNote() {
    final note = widget.scene['context_description']?.toString().trim() ?? '';
    if (note.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_rounded, size: 20, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '當時的情境',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyList(List<dynamic> vocabs) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 當初拍照時輸入的情境原文，幫助日後回想當時的場景
            _buildContextNote(),
            // 拍照後練習造句的紀錄，點一筆可再看語法小教室
            _buildSentenceSection(vocabs),
            Text(
              '在這個場景中識別出 ${vocabs.length} 個單字',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ...vocabs.map((vocab) => VocabCard(vocab: vocab)).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 練習造句紀錄：預設列最近 3 筆，可展開全部；右上角「再造一句」
  Widget _buildSentenceSection(List<dynamic> vocabs) {
    final records = _records;
    final shown = records == null
        ? <Map<String, dynamic>>[]
        : (_showAllRecords ? records : records.take(3).toList());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  records == null || records.isEmpty ? '練習造句' : '練習造句紀錄（${records.length}）',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
              if (vocabs.isNotEmpty && _photoId != null)
                TextButton.icon(
                  onPressed: () => _practice(vocabs),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(records == null || records.isEmpty ? '造一句' : '再造一句'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
            ],
          ),
          if (records == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                _recordsFailed ? '造句紀錄載入失敗，請稍後再試' : '還沒有用這張照片造過句，用照片裡的單字試試看吧！',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textGrey),
              ),
            )
          else ...[
            ...shown.map(_buildRecordTile),
            if (records.length > 3)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showAllRecords = !_showAllRecords),
                  child: Text(_showAllRecords ? '收合' : '顯示全部 ${records.length} 筆'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordTile(Map<String, dynamic> r) {
    final result = Map<String, dynamic>.from(r['result'] as Map? ?? {});
    final isValid = r['is_valid'] == true;
    final corrections = (result['corrections'] as List? ?? []).whereType<Map>().toList();
    final accent = isValid ? AppColors.primary : const Color(0xFFE08A1E);
    final hint = isValid
        ? '完全正確'
        : (corrections.isEmpty ? '看 AI 老師的回饋' : '${corrections.length} 個地方可以更好');

    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 8),
      child: Material(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openRecord(r, result, corrections),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(isValid ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (r['sentence'] ?? '').toString(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$hint・${r['created_at'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: accent),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 重開這筆的語法小教室；整句正確時沒有講解，改顯示 AI 老師的回饋
  void _openRecord(Map<String, dynamic> r, Map<String, dynamic> result, List<Map> corrections) {
    final note = (result['grammar_note'] ?? '').toString().trim();
    GrammarTipScreen.show(
      context,
      userSentence: (r['sentence'] ?? '').toString(),
      correctedSentence: (result['corrected_sentence'] ?? r['sentence'] ?? '').toString(),
      corrections: corrections,
      translation: (result['translation'] ?? '').toString(),
      grammarNote: note.isNotEmpty ? note : (result['feedback'] ?? '').toString(),
    );
  }
}
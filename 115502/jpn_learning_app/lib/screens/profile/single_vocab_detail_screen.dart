import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/common/furigana_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 單字詳情（從單字本點進來，一次只看一個字）。
/// 跟拍照結果頁的 VocabCard 同一套視覺（情境例句黃底、分級例句灰底），
/// 但因為整頁只有這個字，多放了：收藏在哪個單字本、在幾張照片出現過、
/// 自己拍照時留下的情境例句（原本從單字本點進來看不到）。
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
  static const Color _amber = Color(0xFFE0A100);

  bool _isLoading = true;
  bool _loadFailed = false; // 連不到後端或後端出錯：顯示「載入失敗」，不要誤導成「例句生成中」
  bool _isStarred = true;
  List<dynamic> _sentences = [];
  List<dynamic> _contextSentences = [];
  bool _moreLocked = false;
  int _photoCount = 0;
  String? _folderName;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage('ja-JP');
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final detail = await ApiClient.getVocabDetail(widget.vocabId, userId);
      if (!mounted) return;
      setState(() {
        _isStarred = detail['is_favorited'] ?? true;
        // 後端「系統努力生成例句中」的提示不是真的例句，不當成例句卡顯示
        _sentences = (detail['sentences'] as List? ?? []).where((s) => s['level_name'] != null).toList();
        _contextSentences = detail['context_sentences'] as List? ?? [];
        _moreLocked = detail['more_sentences_locked'] == true;
        _photoCount = (detail['photo_count'] as num?)?.toInt() ?? 0;
        _folderName = detail['folder_name']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage('ja-JP');
    await _flutterTts.speak(text);
  }

  Future<void> _toggleStar() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    // 樂觀更新：先讓星星變色，失敗再退回
    setState(() => _isStarred = !_isStarred);

    bool success;
    if (_isStarred) {
      final result = await ApiClient.collectVocab(userId, widget.vocabId);
      success = !result.containsKey('error');
    } else {
      success = await ApiClient.removeFavorite(widget.vocabId, userId);
    }
    if (!mounted) return;

    if (!success) {
      setState(() => _isStarred = !_isStarred);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連線失敗，請稍後再試')));
      return;
    }
    setState(() => _folderName = _isStarred ? '預設相簿' : null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isStarred ? '已加入收藏' : '已從收藏移除')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: Colors.black87, size: AppIcons.navSize),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWordCard(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_loadFailed)
              _buildLoadFailed()
            else ...[
              if (_contextSentences.isNotEmpty) ...[
                _sectionTitle(Icons.auto_awesome, '情境例句', '你拍照時的情境', _amber),
                ..._contextSentences.map((s) => _buildContextCard(s as Map)),
              ],
              _sectionTitle(Icons.menu_book_rounded, '分級例句', null, AppColors.primary),
              if (_sentences.isEmpty)
                const Text('系統努力生成例句中…', style: TextStyle(color: AppColors.textSubtle))
              else
                ..._sentences.map((s) => _buildLevelCard(s as Map)),
              if (_moreLocked) _buildLockedHint(),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- 單字主卡 ----------------
  Widget _buildWordCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.kana.isNotEmpty && widget.kana != widget.word)
                      Text(widget.kana,
                          style: const TextStyle(fontSize: 16, color: AppColors.textGrey, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(widget.word,
                            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                        _speakButton(() => _speak(widget.kana.isNotEmpty ? widget.kana : widget.word), size: 22),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _toggleStar,
                tooltip: _isStarred ? '取消收藏' : '加入收藏',
                icon: Icon(
                  _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _isStarred ? Colors.amber : Colors.grey.shade300,
                  size: 36,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5, height: 1),
          ),
          const Text('詞彙說明', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSubtle)),
          const SizedBox(height: 6),
          Text(widget.meaning,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.4)),
          if (_folderName != null || _photoCount > 0) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_folderName != null) _infoChip(Icons.bookmark_rounded, '收藏於「$_folderName」'),
                if (_photoCount > 0) _infoChip(Icons.photo_camera_rounded, '出現在 $_photoCount 張照片'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }

  // ---------------- 例句區 ----------------
  Widget _sectionTitle(IconData icon, String title, String? sub, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSubtle)),
          ],
        ],
      ),
    );
  }

  /// 情境例句：黃底，下面標出是哪張照片、哪一天
  Widget _buildContextCard(Map s) {
    final text = (s['text'] ?? '').toString();
    final translation = (s['translation'] ?? '').toString();
    final source = [s['photo_title'], s['date']].where((v) => v != null && '$v'.trim().isNotEmpty).join(' · ');

    return _sentenceCard(
      background: const Color(0xFFFFF8E1),
      border: _amber.withOpacity(0.35),
      speakColor: _amber,
      text: text,
      translation: translation,
      footer: source.isEmpty
          ? null
          : Row(
              children: [
                const Icon(Icons.photo_outlined, size: 13, color: AppColors.textSubtle),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(source,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSubtle)),
                ),
              ],
            ),
    );
  }

  /// 分級例句：白底，上方小標籤標示難度
  Widget _buildLevelCard(Map s) {
    return _sentenceCard(
      background: Colors.white,
      border: const Color(0xFFEEEEEE),
      speakColor: AppColors.primary,
      header: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
        child: Text((s['level_name'] ?? '').toString(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
      ),
      text: (s['text'] ?? '').toString(),
      translation: (s['translation'] ?? '').toString(),
    );
  }

  Widget _sentenceCard({
    required Color background,
    required Color border,
    required Color speakColor,
    required String text,
    required String translation,
    Widget? header,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header != null) header,
                FuriganaText(text: text, fontSize: 17, textColor: AppColors.textDark),
                if (translation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(translation, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textGrey)),
                ],
                if (footer != null) ...[const SizedBox(height: 8), footer],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _speakButton(() => _speak(FuriganaText.cleanFuriganaForTts(text)), color: speakColor),
        ],
      ),
    );
  }

  Widget _buildLoadFailed() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.mutedLight),
          const SizedBox(height: 8),
          const Text('例句載入失敗', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text('請確認網路連線，或稍後再試一次', style: TextStyle(fontSize: 13, color: AppColors.textSubtle)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _fetchDetail,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新載入'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedHint() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(12)),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSubtle),
          SizedBox(width: 8),
          Expanded(
            child: Text('提升稱號後，可以看到更進階的例句',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }

  Widget _speakButton(VoidCallback onTap, {Color color = AppColors.primary, double size = 18}) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(Icons.volume_up_rounded, size: size, color: color),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:jpn_learning_app/utils/constants.dart';

import 'single_vocab_detail_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final int? folderId;
  final String folderName;
  final List<Map<String, dynamic>> allFolders;

  const FolderDetailScreen({
    Key? key,
    required this.folderId,
    required this.folderName,
    required this.allFolders,
  }) : super(key: key);

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

/// 單字本裡的排序方式
enum _VocabSort { newest, oldest, kana, shortest, longest }

const Map<_VocabSort, String> _sortLabels = {
  _VocabSort.newest: '最新收藏',
  _VocabSort.oldest: '最舊收藏',
  _VocabSort.kana: '五十音順',
  _VocabSort.shortest: '字數少 → 多',
  _VocabSort.longest: '字數多 → 少',
};

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  // 用 static 記住上次選的排序，換一個單字本進來也沿用（App 重開會回到預設）
  static _VocabSort _lastSort = _VocabSort.newest;

  bool _isLoading = true;
  List<Map<String, dynamic>> _vocabs = [];
  _VocabSort _sort = _lastSort;
  final FlutterTts _flutterTts = FlutterTts();

  /// 片假名轉平假名，讓「ラーメン」和「らいねん」能排在一起比
  String _kanaKey(Map<String, dynamic> vocab) {
    final kana = (vocab['kana'] ?? '').toString();
    final source = kana.isNotEmpty ? kana : (vocab['word'] ?? '').toString();
    return String.fromCharCodes(
      source.runes.map((c) => (c >= 0x30A1 && c <= 0x30F6) ? c - 0x60 : c),
    );
  }

  int _compareCollected(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = DateTime.tryParse((a['collected_at'] ?? '').toString());
    final tb = DateTime.tryParse((b['collected_at'] ?? '').toString());
    if (ta != null && tb != null) {
      final c = ta.compareTo(tb);
      if (c != 0) return c;
    } else if (ta != null || tb != null) {
      // 沒有收藏時間的舊資料當作最早收藏
      return ta == null ? -1 : 1;
    }
    return ((a['user_vocab_id'] ?? 0) as num).compareTo((b['user_vocab_id'] ?? 0) as num);
  }

  int _compareLength(Map<String, dynamic> a, Map<String, dynamic> b) {
    final la = (a['word'] ?? '').toString().runes.length;
    final lb = (b['word'] ?? '').toString().runes.length;
    return la.compareTo(lb);
  }

  void _applySort() {
    int byKana(Map<String, dynamic> a, Map<String, dynamic> b) => _kanaKey(a).compareTo(_kanaKey(b));

    switch (_sort) {
      case _VocabSort.newest:
        _vocabs.sort((a, b) => _compareCollected(b, a));
        break;
      case _VocabSort.oldest:
        _vocabs.sort(_compareCollected);
        break;
      case _VocabSort.kana:
        _vocabs.sort(byKana);
        break;
      case _VocabSort.shortest:
        _vocabs.sort((a, b) {
          final c = _compareLength(a, b);
          return c != 0 ? c : byKana(a, b);
        });
        break;
      case _VocabSort.longest:
        _vocabs.sort((a, b) {
          final c = _compareLength(b, a);
          return c != 0 ? c : byKana(a, b);
        });
        break;
    }
  }

  void _changeSort(_VocabSort sort) {
    setState(() {
      _sort = sort;
      _lastSort = sort;
      _applySort();
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ja-JP");
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("ja-JP");
    await _flutterTts.speak(text);
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadVocabs();
  }

  Future<void> _loadVocabs() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final res = await ApiClient.getFolderVocabs(userId, folderId: widget.folderId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.containsKey('vocabs')) {
        _vocabs = List<Map<String, dynamic>>.from(res['vocabs']);
        _applySort();
      }
    });
  }

  void _showMoveDialog(Map<String, dynamic> vocab) {
    final otherFolders = widget.allFolders.where((f) => f['id'] != widget.folderId).toList();

    if (otherFolders.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('無法移動'),
          content: const Text('目前沒有其他單字本，請先建立一個新的單字本。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '把「${vocab['word']}」移到…',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: otherFolders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final folder = otherFolders[i];
                    final isDefault = folder['is_default'] == true;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final res = await ApiClient.moveVocab(
                          vocab['user_vocab_id'],
                          targetFolderId: folder['id'],
                        );
                        if (!mounted) return;
                        if (res['error'] != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('已移到「${folder['name']}」')));
                          _loadVocabs();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lightBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: isDefault ? Colors.amber.withOpacity(0.15) : AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDefault ? Icons.star_rounded : Icons.folder_rounded,
                                color: isDefault ? Colors.amber.shade600 : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(folder['name'] ?? '未命名',
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                  const SizedBox(height: 2),
                                  Text('${folder['count'] ?? 0} 個單字',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSubtle)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: Colors.black87, size: AppIcons.navSize),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.folderName,
                style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w800)),
            if (!_isLoading)
              Text('${_vocabs.length} 個單字', style: const TextStyle(color: AppColors.textSubtle, fontSize: 12)),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _vocabs.isEmpty
              ? Column(
                  children: [
                    // 空的單字本也照樣顯示排序鈕，位置跟有單字時一致
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildSortBar(),
                    ),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border_rounded, size: 56, color: AppColors.mutedLight),
                          SizedBox(height: 12),
                          Text('這個單字本還沒有單字', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('在單字頁按星星就能收藏進來', style: TextStyle(color: AppColors.textSubtle, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadVocabs,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _vocabs.length + 1,
                    itemBuilder: (context, index) =>
                        index == 0 ? _buildSortBar() : _buildVocabCard(_vocabs[index - 1]),
                  ),
                ),
    );
  }

  /// 清單最上面的排序鈕：直接顯示目前的排序方式，點了跳出選單
  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<_VocabSort>(
          tooltip: '排序方式',
          color: Colors.white,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          initialValue: _sort,
          onSelected: _changeSort,
          itemBuilder: (_) => _VocabSort.values.map((s) {
            final selected = s == _sort;
            return PopupMenuItem<_VocabSort>(
              value: s,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sortLabels[s]!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? AppColors.primary : AppColors.textDark,
                      ),
                    ),
                  ),
                  if (selected) const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            );
          }).toList(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _sortLabels[_sort]!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                const Icon(Icons.arrow_drop_down_rounded, size: 24, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 一個單字一張卡：左邊假名＋單字＋中文，右邊發音和「移到其他單字本」
  Widget _buildVocabCard(Map<String, dynamic> vocab) {
    final word = (vocab['word'] ?? '').toString();
    final kana = (vocab['kana'] ?? '').toString();
    final meaning = (vocab['meaning'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SingleVocabDetailScreen(
                  vocabId: vocab['vocab_id'] ?? vocab['id'] ?? 0,
                  word: word,
                  kana: kana,
                  meaning: meaning,
                ),
              ),
            );
            // 在單字頁取消收藏的話，回來時清單要跟著更新
            if (mounted) _loadVocabs();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kana.isNotEmpty && kana != word)
                        Text(kana, style: const TextStyle(fontSize: 13, color: AppColors.textSubtle)),
                      Text(word,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(meaning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.4)),
                    ],
                  ),
                ),
                InkResponse(
                  onTap: () => _speak(kana.isNotEmpty ? kana : word),
                  radius: 24,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.volume_up_rounded, size: 20, color: AppColors.primary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline, color: AppColors.textSubtle),
                  onPressed: () => _showMoveDialog(vocab),
                  tooltip: '移到其他單字本',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _vocabs = [];
  final FlutterTts _flutterTts = FlutterTts();

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
              ? const Center(
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
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadVocabs,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _vocabs.length,
                    itemBuilder: (context, index) => _buildVocabCard(_vocabs[index]),
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

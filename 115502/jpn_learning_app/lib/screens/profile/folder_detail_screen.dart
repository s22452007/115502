import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';


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
  static const Color primaryGreen = Color(0xFF6AA86B);
  static const Color textColor = Color(0xFF333333);
  static const Color subColor = Color(0xFF9E9E9E);

  bool _isLoading = true;
  List<Map<String, dynamic>> _vocabs = [];

  @override
  void initState() {
    super.initState();
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
          content: const Text('目前沒有其他資料夾，請先建立一個新的收藏夾。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了', style: TextStyle(color: primaryGreen)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '移動「${vocab['word']}」到...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 16),
            ...otherFolders.map((folder) => ListTile(
              leading: Icon(
                folder['is_default'] == true ? Icons.auto_awesome_rounded : Icons.folder_rounded,
                color: primaryGreen,
              ),
              title: Text(folder['name'] ?? '未命名'),
              subtitle: Text('${folder['count'] ?? 0} 個單字'),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移動到「${folder['name']}」')));
                  _loadVocabs();
                }
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.folderName,
          style: const TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _vocabs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('這個資料夾還沒有單字', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVocabs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vocabs.length,
                    itemBuilder: (context, index) {
                      return _buildVocabCard(_vocabs[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildVocabCard(Map<String, dynamic> vocab) {
    return GestureDetector(
      onTap: () {
        // 跳轉到全新的單一單字詳情頁
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SingleVocabDetailScreen(
              vocabId: vocab['vocab_id'] ?? vocab['id'] ?? 0, 
              word: vocab['word'] ?? '',
              kana: vocab['kana'] ?? '',
              meaning: vocab['meaning'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  vocab['word'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vocab['kana'] ?? '',
                    style: const TextStyle(fontSize: 14, color: subColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vocab['meaning'] ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_outline, color: Colors.grey),
              onPressed: () => _showMoveDialog(vocab),
              tooltip: '移動到其他資料夾',
            ),
          ],
        ),
      ),
    );
  }
}
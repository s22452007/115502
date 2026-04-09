import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class PhotoFolderV2Screen extends StatefulWidget {
  const PhotoFolderV2Screen({Key? key}) : super(key: key);

  @override
  State<PhotoFolderV2Screen> createState() => _PhotoFolderV2ScreenState();
}

class _PhotoFolderV2ScreenState extends State<PhotoFolderV2Screen> {
  static const Color primaryGreen = Color(0xFF6AA86B);
  static const Color bgColor = Color(0xFFF9F9F9);
  static const Color textColor = Color(0xFF333333);
  static const Color subColor = Color(0xFF9E9E9E);

  bool _isLoading = true;
  List<Map<String, dynamic>> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final res = await ApiClient.fetchUserFavorites(userId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.containsKey('favorites')) {
        _folders = List<Map<String, dynamic>>.from(res['favorites']);
      }
    });
  }

  void _showAddFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增收藏夾', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '輸入資料夾名稱',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryGreen, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              final userId = context.read<UserProvider>().userId;
              if (userId == null) return;

              await ApiClient.createFolder(userId, name);
              _loadFolders();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text('建立', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(Map<String, dynamic> folder) {
    final controller = TextEditingController(text: folder['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('編輯名稱', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryGreen, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await ApiClient.renameFolder(folder['id'], name);
              _loadFolders();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text('儲存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(Map<String, dynamic> folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('確定要刪除「${folder['name']}」嗎？\n裡面的單字會移回預設相簿。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiClient.deleteFolder(folder['id']);
              _loadFolders();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<UserProvider>().userId == null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的收藏夾',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
              backgroundColor: primaryGreen,
              onPressed: _showAddFolderDialog,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: isGuest
          ? _buildGuestView()
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryGreen))
              : RefreshIndicator(
                  onRefresh: _loadFolders,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 統計卡片
                      _buildStatsCard(),
                      const SizedBox(height: 20),

                      // 資料夾列表
                      if (_folders.isEmpty)
                        _buildEmptyState()
                      else
                        ..._folders.map((f) => _buildFolderCard(f)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsCard() {
    final totalVocabs = _folders.fold<int>(0, (sum, f) => sum + ((f['count'] ?? 0) as int));
    final folderCount = _folders.where((f) => f['is_default'] != true).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6AA86B), Color(0xFF8FC98F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '我的學習收藏',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '持續收藏，累積你的日文實力！',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildStatItem('$totalVocabs', '單字'),
          const SizedBox(width: 16),
          _buildStatItem('$folderCount', '資料夾'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_add_outlined,
              size: 40,
              color: primaryGreen.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '還沒有收藏任何單字',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去拍照探索場景，收藏喜歡的單字吧！',
            style: TextStyle(fontSize: 14, color: subColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    final isDefault = folder['is_default'] == true;
    final count = folder['count'] ?? 0;
    final folderId = folder['id'];

    // 不同資料夾用不同顏色
    final colors = [
      const Color(0xFF6AA86B),
      const Color(0xFF6B9BD2),
      const Color(0xFFD28B6B),
      const Color(0xFF8B6B9E),
      const Color(0xFFD2C36B),
    ];
    final color = isDefault ? primaryGreen : colors[(folderId ?? 0) % colors.length];

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FolderDetailScreen(
              folderId: folderId,
              folderName: folder['name'] ?? '預設相簿',
              allFolders: _folders,
            ),
          ),
        );
        _loadFolders(); // 回來時重新載入
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isDefault ? Icons.auto_awesome_rounded : Icons.folder_rounded,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder['name'] ?? '未命名',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count 個單字',
                    style: const TextStyle(fontSize: 13, color: subColor),
                  ),
                ],
              ),
            ),
            if (!isDefault)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'rename') _showRenameFolderDialog(folder);
                  if (value == 'delete') _showDeleteFolderDialog(folder);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('重新命名')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('刪除資料夾', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 80, color: subColor),
          const SizedBox(height: 24),
          const Text(
            '登入即可使用收藏夾功能',
            style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 資料夾內容頁（顯示單字列表 + 移動功能）
// ==========================================
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
    final otherFolders = widget.allFolders
        .where((f) => f['id'] != widget.folderId)
        .toList();

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'])),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已移動到「${folder['name']}」')),
                  );
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
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
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
    return Container(
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
          // 單字大字（隨字體大小自動成長）
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
          // 移動按鈕
          IconButton(
            icon: const Icon(Icons.drive_file_move_outline, color: Colors.grey),
            onPressed: () => _showMoveDialog(vocab),
            tooltip: '移動到其他資料夾',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

import 'package:jpn_learning_app/widgets/profile/folder/folder_card.dart';
import 'folder_detail_screen.dart';

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
        title: const Text(
          '新增收藏夾',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
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
        title: const Text(
          '編輯名稱',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
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
        title: const Text(
          '確認刪除',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的收藏夾',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadFolders,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  if (_folders.isEmpty)
                    _buildEmptyState()
                  else
                    // 使用抽離出去的 FolderCard 積木
                    ..._folders.map(
                      (f) => FolderCard(
                        folder: f,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderDetailScreen(
                                folderId: f['id'],
                                folderName: f['name'] ?? '預設相簿',
                                allFolders: _folders,
                              ),
                            ),
                          );
                          _loadFolders();
                        },
                        onRename: _showRenameFolderDialog,
                        onDelete: _showDeleteFolderDialog,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final totalVocabs = _folders.fold<int>(
      0,
      (sum, f) => sum + ((f['count'] ?? 0) as int),
    );
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
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
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

  Widget _buildGuestView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 80, color: subColor),
          const SizedBox(height: 24),
          const Text(
            '登入即可使用收藏夾功能',
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

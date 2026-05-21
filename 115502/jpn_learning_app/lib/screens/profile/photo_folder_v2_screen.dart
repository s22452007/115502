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
  int _vocabSlot = 50;
  int _vocabCount = 0;
  bool _isExpanding = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final results = await Future.wait([
      ApiClient.fetchUserFavorites(userId),
      ApiClient.getUsageStatus(userId),
    ]);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final favRes = results[0];
      final usageRes = results[1];
      if (favRes.containsKey('favorites')) {
        _folders = List<Map<String, dynamic>>.from(favRes['favorites']);
      }
      if (!usageRes.containsKey('error')) {
        _vocabSlot = (usageRes['vocab_slot'] as num?)?.toInt() ?? 50;
        _vocabCount = (usageRes['vocab_count'] as num?)?.toInt() ?? 0;
      }
    });
  }

  Future<void> _loadFolders() => _loadAll();

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

  Future<void> _expandVocabSlot() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final isPremium = context.read<UserProvider>().isPremium;
    final feature = isPremium ? 'vocab_expand_premium' : 'vocab_expand';
    final cost = isPremium ? 35 : 50;

    setState(() => _isExpanding = true);
    final res = await ApiClient.spendPoints(
      userId: userId,
      points: cost,
      feature: feature,
    );
    if (!mounted) return;
    setState(() => _isExpanding = false);

    if (res.containsKey('error')) {
      final errMsg = res['error'].toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg.contains('點數不足') ? '點數不足，請先購買點數' : errMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      final newPts = (res['total_points'] as num?)?.toInt();
      if (newPts != null) context.read<UserProvider>().setJPts(newPts);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('擴充成功！收藏空間 +50 個'), backgroundColor: Color(0xFF6AA86B)),
      );
    }
  }

  Widget _buildStatsCard() {
    final folderCount = _folders.where((f) => f['is_default'] != true).length;
    final ratio = _vocabSlot > 0 ? (_vocabCount / _vocabSlot).clamp(0.0, 1.0) : 0.0;
    final remaining = (_vocabSlot - _vocabCount).clamp(0, _vocabSlot);
    final isFull = _vocabCount >= _vocabSlot;
    final isNearFull = !isFull && _vocabCount >= (_vocabSlot * 0.8).ceil();
    final isPremium = context.read<UserProvider>().isPremium;
    final expandCost = isPremium ? 35 : 50;

    return Column(
      children: [
        // ── 主統計卡片 ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6AA86B), Color(0xFF8FC98F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '我的學習收藏',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '持續收藏，累積你的日文實力！',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatItem('$_vocabCount', '單字'),
                  const SizedBox(width: 16),
                  _buildStatItem('$folderCount', '資料夾'),
                ],
              ),
              const SizedBox(height: 16),
              // ── 空間使用進度條 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已使用空間：$_vocabCount / $_vocabSlot 個',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '還可收藏 $remaining 個',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? Colors.red.shade300 : isNearFull ? Colors.orange.shade300 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 警告 / 擴充區塊 ─────────────────────────────
        if (isFull) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 6),
                  Text('收藏空間已滿！', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isExpanding ? null : _expandVocabSlot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6AA86B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isExpanding
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('花 $expandCost 點擴充 +50 個空間', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isNearFull) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 6),
              Text('收藏空間即將用完！', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
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

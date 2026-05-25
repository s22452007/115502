import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

import 'package:jpn_learning_app/screens/profile/folder_card.dart';
import 'folder_detail_screen.dart';

class PhotoFolderV2Screen extends StatefulWidget {
  const PhotoFolderV2Screen({Key? key}) : super(key: key);

  @override
  State<PhotoFolderV2Screen> createState() => _PhotoFolderV2ScreenState();
}

class _PhotoFolderV2ScreenState extends State<PhotoFolderV2Screen> {
  static const Color bgColor = Color(0xFFF4F7F5);     
  static const Color textColor = Color(0xFF2C3E50);   
  static const Color subColor = Color(0xFF8E9AAB);    

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
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '新增收藏夾',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontWeight: FontWeight.w600, color: textColor),
          decoration: InputDecoration(
            hintText: '輸入資料夾名稱',
            hintStyle: const TextStyle(color: subColor),
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('建立', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '編輯名稱',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontWeight: FontWeight.w600, color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await ApiClient.renameFolder(folder['id'], name);
              _loadFolders();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('儲存', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(Map<String, dynamic> folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('確認刪除', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
          ],
        ),
        content: Text(
          '確定要刪除「${folder['name']}」嗎？\n裡面的單字會移回預設相簿。',
          style: const TextStyle(color: textColor, fontWeight: FontWeight.w600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiClient.deleteFolder(folder['id']);
              _loadFolders();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('刪除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的收藏夾',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              elevation: 0, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), 
              onPressed: _showAddFolderDialog,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
      body: isGuest
          ? _buildGuestView()
          : _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: _loadFolders,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), 
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  
                  if (_folders.isEmpty)
                    _buildEmptyState()
                  else
                    // 🌟 一排 3 個小型網格排列
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), 
                      itemCount: _folders.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,         // 🌟 改為一排 3 個
                        crossAxisSpacing: 12,      // 卡片左右間距
                        mainAxisSpacing: 16,       // 卡片上下間距
                        childAspectRatio: 0.65,    // 🌟 調整比例(寬/高)，預留更多空間給下方文字
                      ),
                      itemBuilder: (context, index) {
                        final f = _folders[index];
                        return FolderCard(
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
                        );
                      },
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
          content: Text(errMsg.contains('點數不足') ? '點數不足，請先購買點數' : errMsg, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      final newPts = (res['total_points'] as num?)?.toInt();
      if (newPts != null) context.read<UserProvider>().setJPts(newPts);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('擴充成功！收藏空間 +50 個', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(28),
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
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '持續收藏，累積你的日文實力！',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatItem('$_vocabCount', '單字'),
                  const SizedBox(width: 12),
                  _buildStatItem('$folderCount', '資料夾'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已使用：$_vocabCount / $_vocabSlot 個',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '還可收藏 $remaining 個',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Colors.black.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? const Color(0xFFFF5252) : isNearFull ? const Color(0xFFFFD740) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isFull) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.error_rounded, color: Color(0xFFE53935), size: 22),
                  const SizedBox(width: 8),
                  const Text('收藏空間已滿！', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isExpanding ? null : _expandVocabSlot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isExpanding
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('花 $expandCost J-Pts 擴充 +50 空間', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isNearFull) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.warning_rounded, color: Color(0xFFF57F17), size: 22),
              const SizedBox(width: 8),
              const Text('收藏空間即將用完！', style: TextStyle(color: Color(0xFFF57F17), fontWeight: FontWeight.w800, fontSize: 14)),
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmark_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '還沒有收藏任何單字',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去拍照探索場景，收藏喜歡的單字吧！',
            style: TextStyle(fontSize: 14, color: subColor, fontWeight: FontWeight.w600),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 60, color: subColor),
          ),
          const SizedBox(height: 24),
          const Text(
            '登入即可使用收藏夾功能',
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
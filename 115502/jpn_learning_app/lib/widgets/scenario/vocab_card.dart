import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class VocabCard extends StatefulWidget {
  final dynamic vocab;

  const VocabCard({Key? key, required this.vocab}) : super(key: key);

  @override
  State<VocabCard> createState() => _VocabCardState();
}

class _VocabCardState extends State<VocabCard> {
  bool _isLoading = true;
  bool _isStarred = false;
  List<dynamic> _sentences = []; 

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final userId = context.read<UserProvider>().userId;
    try {
      final detail = await ApiClient.getVocabDetail(
        widget.vocab['vocab_id'],
        userId!,
      );
      if (mounted) {
        setState(() {
          _isStarred = detail['is_favorited'] ?? false;
          _sentences = detail['sentences'] ?? []; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 點擊星星的邏輯 (加入與取消)
  // ==========================================
  Future<void> _toggleStar() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    // 【情境 A】取消收藏
    if (_isStarred) {
      final success = await ApiClient.removeFavorite(
        widget.vocab['vocab_id'],
        userId,
      );

      ScaffoldMessenger.of(context).clearSnackBars();

      if (success) {
        setState(() => _isStarred = false); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已取消收藏'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消失敗，請稍後再試')));
      }
      return; 
    }

    // 【情境 B】加入收藏 (彈出資料夾視窗)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '請選擇要加入的單字本',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),

                // 建立新單字本按鈕
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                  title: const Text(
                    '建立新單字本',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext); // 先關閉底部選單
                    _showCreateFolderDialog(userId); // 呼叫彈出輸入框的函式
                  },
                ),
                const Divider(height: 1),

                FutureBuilder<Map<String, dynamic>>(
                  future: ApiClient.fetchUserFavorites(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("載入資料夾失敗，請稍後再試"),
                      );
                    }

                    final data = snapshot.data ?? {};
                    final folders = data['favorites'] as List<dynamic>? ?? [];

                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final folder = folders[index];
                          final isDefault = folder['is_default'] == true;

                          return ListTile(
                            leading: Icon(
                              isDefault ? Icons.star : Icons.folder,
                              color: isDefault ? Colors.amber : const Color(0xFF8B6B9E),
                              size: 28,
                            ),
                            title: Text(
                              folder['name'] ?? '未命名',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('已收錄 ${folder['count']} 個單字'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _executeCollection(userId, folder['id']);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 彈出建立單字本的輸入框
  // ==========================================
  Future<void> _showCreateFolderDialog(int userId) async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('建立新單字本', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '請輸入單字本名稱',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final folderName = controller.text.trim();
              if (folderName.isNotEmpty) {
                Navigator.pop(ctx); 
                
                // ⚠️ 備忘：未來這裡要串接「建立資料夾 API」
                /*
                try {
                  final newFolderId = await ApiClient.createFolder(userId, folderName);
                  if (newFolderId != null) {
                    _executeCollection(userId, newFolderId);
                  }
                } catch (e) { ... }
                */

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('前端 UI 完成！準備串接建立「$folderName」的 API 🚀')),
                );
              }
            },
            child: const Text('建立並收藏', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 真正發送 API 把單字塞入指定資料夾的函式
  Future<void> _executeCollection(int userId, int? folderId) async {
    final result = await ApiClient.collectVocab(
      userId,
      widget.vocab['vocab_id'],
      folderId: folderId,
    );

    ScaffoldMessenger.of(context).clearSnackBars();

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
    } else {
      setState(() => _isStarred = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已成功加入單字本！⭐'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上半部：日文、假名、星星
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vocab['kana'],
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.vocab['word'],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              // 星星按鈕
              GestureDetector(
                onTap: _toggleStar,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Icon(
                        _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                        color: _isStarred ? Colors.amber : Colors.grey.shade300,
                        size: 40,
                      ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
          ),

          // 下半部：詞彙說明與例句
          const Text(
            '詞彙說明',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.vocab['meaning'],
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // 鷹架式例句區塊
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _sentences
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.volume_up, color: Colors.blueGrey, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['level_name'] ?? s['level'] ?? '提示', 
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  s['text'] ?? '暫無例句', 
                                  style: const TextStyle(fontSize: 15, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
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

    // 【情境 B】加入收藏 (彈出高質感資料夾視窗)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // 讓內容多時可以自然延展
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)), // 圓角加大更圓潤
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), // 增加四周呼吸感
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 頂部拖拉指示條 (小灰線)
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. 標題設計
                const Text(
                  '請選擇要加入的單字本',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 20),

                // 3. 「建立新單字本」按鈕 (高質感卡片風)
                InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCreateFolderDialog(userId);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08), // 柔和的微透明綠底
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          '建立新單字本',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. 資料夾列表
                FutureBuilder<Map<String, dynamic>>(
                  future: ApiClient.fetchUserFavorites(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12), // 用留白取代死板的黑線
                        itemBuilder: (context, index) {
                          final folder = folders[index];
                          final isDefault = folder['is_default'] == true;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _executeCollection(userId, folder['id']);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  // 圓形背景 Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDefault ? Colors.amber.withOpacity(0.15) : const Color(0xFF8B6B9E).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isDefault ? Icons.star_rounded : Icons.folder_rounded,
                                      color: isDefault ? Colors.amber.shade600 : const Color(0xFF8B6B9E),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 標題與數量
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folder['name'] ?? '未命名',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '已收錄 ${folder['count']} 個單字',
                                          style: TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 箭頭引導
                                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
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
        backgroundColor: const Color(0xFFE6EBE1), 
        // 圓潤的對話框邊角
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), 
        titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        title: const Text(
          '新增收藏夾', // 改為圖一的文案
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF1D1D1D),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 18), // 讓輸入的字體稍微大一點點，更好看
          decoration: InputDecoration(
            hintText: '輸入資料夾名稱', // 改為圖一的文案
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 18),
            filled: false,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 24, bottom: 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              // 4. 換上圖一那種溫和的抹茶綠色按鈕
              backgroundColor: const Color(0xFF6CA86B), 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // 圓角按鈕
              ),
              elevation: 0, // 扁平化，拔掉厚重的陰影
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
                  SnackBar(content: Text('已建立「$folderName」並收藏！🚀')),
                );
              }
            },
            child: const Text(
              '建立並收藏',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
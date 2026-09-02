import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 2. 匯入跳轉的相簿詳細頁面
import 'package:jpn_learning_app/screens/scenario/scenario_detail_screen.dart';
import 'package:jpn_learning_app/screens/scenario/theme_collection_screen.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';

class ResultGalleryV2Screen extends StatefulWidget {
  const ResultGalleryV2Screen({Key? key}) : super(key: key);

  @override
  State<ResultGalleryV2Screen> createState() => _ResultGalleryV2ScreenState();
}

class _ResultGalleryV2ScreenState extends State<ResultGalleryV2Screen> {
  /// 一次載入幾張。照片會隨著天天拍照無限累積，不能再一口氣全撈。
  static const int _pageSize = 20;

  final List<dynamic> _photos = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  /// 重新從第一頁載入（初次進入、改名、從子頁返回都走這裡）
  Future<void> _loadFirstPage() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() {
      _initialLoading = true;
      _error = null;
    });

    try {
      final page = await ApiClient.getUnlockedScenesPage(userId,
          limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll((page['scenes'] as List?) ?? []);
        _total = (page['total'] ?? _photos.length) as int;
        _hasMore = page['has_more'] == true;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await ApiClient.getUnlockedScenesPage(userId,
          limit: _pageSize, offset: _photos.length);
      if (!mounted) return;
      setState(() {
        _photos.addAll((page['scenes'] as List?) ?? []);
        _total = (page['total'] ?? _total) as int;
        _hasMore = page['has_more'] == true;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('載入更多失敗，請再試一次')));
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    int photoId,
    String currentName,
  ) async {
    final TextEditingController titleController = TextEditingController(
      text: currentName,
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改照片名稱'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '照片名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != currentName) {
                await ApiClient.renamePhoto(photoId, newTitle);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('確認修改', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // 對話框關閉後，重新載入清單
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return SubPageTemplate(
      title: '我的單字探險',
      body: userId == null
          ? const Center(
              child: Text(
                '請先登入才能查看單字探險喔！',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // 主題收集冊的入口（原本掛在首頁「查看全部」，改放這裡）
                _buildThemeCollectionEntry(context),
                Expanded(child: _buildSceneList()),
              ],
            ),
    );
  }

  /// 收集冊入口：講清楚它跟下面的照片清單有什麼不同
  Widget _buildThemeCollectionEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ThemeCollectionScreen()),
          ).then((_) {
            if (mounted) _loadFirstPage();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.collections_bookmark_outlined,
                  size: 22, color: AppColors.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主題收集冊',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '把拍過的照片依生活情境集成一本本冊子',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSceneList() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      debugPrint('取得單字探險發生錯誤: $_error');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            '載入失敗原因：\n$_error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_photos.isEmpty) {
      return const Center(
        child: Text(
          '還沒有解鎖任何場景喔！\n趕快去拍照探索吧！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            height: 1.5,
          ),
        ),
      );
    }

    final scenarios = _photos;
    return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  // 最後多一格放「載入更多」
                  itemCount: scenarios.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == scenarios.length) {
                      return _buildLoadMore();
                    }
                    final scene = scenarios[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // 把整個 scene 的 Map 傳給詳細頁面
                            builder: (context) =>
                                ScenarioDetailScreen(scene: scene),
                          ),
                        ).then((_) {
                          // 從詳細畫面返回時，重新整理清單
                          if (mounted) _loadFirstPage();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey[200],
                              ),
                              child: scene['image_path'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      // 修正照片破圖：改為 /static/photos/，並且加上 errorBuilder 防止白畫面
                                      child: Image.network(
                                        scene['image_path'].startsWith('http')
                                            ? scene['image_path']
                                            : '${ApiClient.baseUrl.replaceAll('/api', '')}/static/photos/${scene['image_path'].split('/').last}',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: const Color(0xFFF0F0F0),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.image_not_supported_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      ),
                                    )
                                  : const Icon(Icons.image, color: Colors.grey),
                            ),

                            // 解決太擠的問題：在這裡加入一個 16 像素的隱形空白寬度
                            const SizedBox(width: 16),

                            // 中間：標題與提示文字
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        // 使用 Flexible 讓字越長佔越多，但不強制佔滿。
                                        child: Text(
                                          scene['scene_name'], // 因為後端改了，這裡會自動印出 custom_title！
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF333333),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow
                                              .ellipsis, // 如果標題太長會自動變成 ...
                                        ),
                                      ),
                                      if (scene['photo_id'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              _showRenameDialog(
                                                context,
                                                scene['photo_id'],
                                                scene['scene_name'],
                                              );
                                            },
                                            child: const Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    // 讓提示文字顯示這張照片解鎖了幾個字
                                    '這張照片解鎖了 ${scene['vocab_count']} 個單字 >',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 右側：日期 (動態從資料庫抓取)
                            Text(
                              scene['unlocked_at'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
    );
  }

  /// 清單底部的「載入更多」；一次再拿 20 張
  Widget _buildLoadMore() {
    final remaining = _total - _photos.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _loadMore,
                child: Text(
                  remaining > 0 ? '載入更多（還有 $remaining 張）' : '載入更多',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

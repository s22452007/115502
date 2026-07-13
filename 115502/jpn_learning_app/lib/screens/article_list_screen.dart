import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/services/article_service.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({Key? key}) : super(key: key);

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  late Future<List<Article>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    // 進入畫面時，取得目前使用者的 ID 並請求 N3 等級的文章
    // (未來可以改成從 UserProvider 讀取使用者真正的等級)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().userId ?? 0;
      setState(() {
        _articlesFuture = ArticleService.getDashboardArticles(userId, 'N3');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '文章練習',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2C3E50)),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 確保 _articlesFuture 已經初始化
    // ignore: unnecessary_null_comparison
    if (_articlesFuture == null) return const SizedBox();

    return FutureBuilder<List<Article>>(
      future: _articlesFuture,
      builder: (context, snapshot) {
        // 載入中狀態 (轉圈圈)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        } 
        // 發生錯誤
        else if (snapshot.hasError) {
          return Center(
            child: Text('載入失敗，請確認伺服器已啟動\n${snapshot.error}', textAlign: TextAlign.center),
          );
        } 
        // 沒資料
        else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('目前沒有文章資料', style: TextStyle(color: Colors.grey)));
        }

        // 成功取得資料，顯示卡片列表
        final articles = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            return _buildArticleCard(articles[index]);
          },
        );
      },
    );
  }

  // 獨立出來的文章卡片元件
  Widget _buildArticleCard(Article article) {
    // 若該主題沒有資料 (預防萬一)
    if (article.id == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // TODO: 下一步，我們會在這裡跳轉到「文章閱讀與朗讀頁面」
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('即將前往閱讀：${article.title}'))
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 主題標籤
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        article.theme,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    // 等級標籤
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                       decoration: BoxDecoration(
                         color: Colors.orange.withOpacity(0.15),
                         borderRadius: BorderRadius.circular(6)
                       ),
                      child: Text(
                        article.level,
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 文章標題
                Text(
                  article.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 12),
                // 底部提示
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('點擊開始閱讀與朗讀', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
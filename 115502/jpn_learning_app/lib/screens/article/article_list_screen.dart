import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/article/article_history_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart'; 
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/services/article_service.dart';
import 'package:jpn_learning_app/screens/article/article_detail_screen.dart'; 
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';


class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({Key? key}) : super(key: key);

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  Future<List<Article>>? _articlesFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArticles();
    });
  }

void _loadArticles() {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId ?? 0;
    
    // 🌟 動態獲取使用者的真實等級，如果沒有設定，預設給 N3
    String userLevel = userProvider.japaneseLevel;
    if (userLevel.isEmpty) {
      userLevel = 'N3'; 
    }

    setState(() {
      _articlesFuture = ArticleService.getDashboardArticles(userId, userLevel);
    });
  }

  // ====================================================
  // 🌟 過濾標題中的 Ruby 假名標籤，還原為純淨文字
  // ====================================================
  String _cleanRubyTags(String htmlString) {
    String noRt = htmlString.replaceAll(RegExp(r'<rt>.*?</rt>'), '');
    return noRt.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return SubPageTemplate(
      title: '文章練習',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_articlesFuture == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return FutureBuilder<List<Article>>(
      future: _articlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        } else if (snapshot.hasError) {
          return Center(
            child: Text('載入失敗，請確認伺服器已啟動\n${snapshot.error}', textAlign: TextAlign.center),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('目前沒有文章資料', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final articles = snapshot.data!;
        articles.sort((a, b) {
          if (a.isUnlocked == b.isUnlocked) return 0;
          return a.isUnlocked ? -1 : 1;
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          // 列表數量加 1，用來放頂部的歷史紀錄按鈕
          itemCount: articles.length + 1,
          itemBuilder: (context, index) {
            // 第 0 項顯示「歷史成績紀錄」按鈕
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('查看我的歷史成績紀錄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ArticleHistoryScreen()),
                    );
                  },
                ),
              );
            }
            // 剩下的項目照常顯示文章卡片 (index 要減 1)
            return _buildArticleCard(articles[index - 1]);
          },
        );
      },
    );
  }

  Widget _buildArticleCard(Article article) {
    if (article.id == 0) return const SizedBox.shrink();

    final bool isUnlocked = article.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnlocked ? Colors.transparent : const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isUnlocked) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArticleDetailScreen(article: article),
                ),
              );
            } else {
              _showUnlockDialog(context, article.id, _cleanRubyTags(article.title), 50);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnlocked ? AppColors.primary.withOpacity(0.1) : const Color(0xFFCBD5E1).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.theme, 
                        style: TextStyle(
                          color: isUnlocked ? AppColors.primary : const Color(0xFF64748B), 
                          fontWeight: FontWeight.bold, 
                          fontSize: 13
                        )
                      ),
                    ),
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                       decoration: BoxDecoration(
                         color: isUnlocked ? Colors.orange.withOpacity(0.15) : const Color(0xFFCBD5E1).withOpacity(0.3), 
                         borderRadius: BorderRadius.circular(6)
                       ),
                      child: Text(
                        article.level, 
                        style: TextStyle(
                          color: isUnlocked ? Colors.orange : const Color(0xFF64748B), 
                          fontWeight: FontWeight.w900, 
                          fontSize: 13
                        )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _cleanRubyTags(article.title), 
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: isUnlocked ? const Color(0xFF2C3E50) : const Color(0xFF94A3B8)
                  )
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isUnlocked ? Icons.menu_book_rounded : Icons.lock_outline_rounded, 
                      size: 16, 
                      color: isUnlocked ? Colors.grey : AppColors.primary
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUnlocked ? '點擊開始閱讀' : '花費 50 J-pts 解鎖此文章', 
                      style: TextStyle(
                        fontSize: 13, 
                        color: isUnlocked ? Colors.grey[600] : AppColors.primary, 
                        fontWeight: FontWeight.w600
                      )
                    ),
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

  // ====================================================
  // 解鎖確認對話框
  // ====================================================
  void _showUnlockDialog(BuildContext context, int articleId, String articleTitle, int cost) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('解鎖文章', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 16),
                Text('確定要花費 $cost J-pts 解鎖「$articleTitle」嗎？', style: const TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: const Color(0xFFF1F5F9), 
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          elevation: 0, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _processUnlock(context, articleId, cost);
                        },
                        child: const Text('確認解鎖', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====================================================
  // 處理後端解鎖邏輯 (前端驗證現有點數)
  // ====================================================
  Future<void> _processUnlock(BuildContext context, int articleId, int cost) async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId ?? 0;
    
    // 🌟 採用你原系統的點數判斷（例如 380 點）

    final currentPoints = userProvider.jPts ?? 0; // ✅ 改用正確的 jPts
    if (currentPoints < cost) {
      _showInsufficientPointsDialog(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在處理中...', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        duration: Duration(seconds: 1),
      ),
    );

    final result = await ApiClient.unlockArticle(userId, articleId, cost);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['_status'] == 200 && result['status'] == 'success') {
      _loadArticles(); // 重新整理畫面
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('文章解鎖成功', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('解鎖失敗: ${result['message'] ?? '系統錯誤'}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        ),
      );
    }
  }

  // ====================================================
  // 點數不足導購對話框 (已串接你的 StoreDashboardScreen)
  // ====================================================
  void _showInsufficientPointsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('J-pts 點數不足', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 16),
                const Text('您的點數餘額不足以解鎖此文章。是否前往儲值中心獲取更多點數？', style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('稍後再說', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFF59E0B), 
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // 關閉對話框
                          // 🌟 完美銜接你原有的商城與會員中心
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const StoreDashboardScreen())
                          );
                        },
                        child: const Text('前往購買', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
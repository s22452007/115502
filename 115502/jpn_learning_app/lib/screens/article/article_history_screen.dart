import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class ArticleHistoryScreen extends StatefulWidget {
  const ArticleHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ArticleHistoryScreen> createState() => _ArticleHistoryScreenState();
}

class _ArticleHistoryScreenState extends State<ArticleHistoryScreen> {
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    // 取得當前使用者 ID (若無則預設為 8 方便測試)
    final userId = context.read<UserProvider>().userId ?? 8;
    _historyFuture = ApiClient.getUserScoreHistory(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5), // 同步閱讀區塊底色
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
        title: const Text(
          '歷史成績紀錄',
          style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (snapshot.hasError) {
            return Center(child: Text('載入失敗：${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 80, color: Colors.black12),
                  SizedBox(height: 16),
                  Text('尚無測驗紀錄，趕快去練習吧！', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final records = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final score = record['score'] ?? 0;
              final points = record['points_earned'] ?? 0;
              final date = record['date'] ?? '';
              final title = record['article_title'] ?? '未知文章';

              // 依分數決定色彩 (綠色/橘色/紅色)
              Color scoreColor = AppColors.primary;
              if (score < 60) {
                scoreColor = const Color(0xFFE74C3C);
              } else if (score < 80) {
                scoreColor = Colors.orange;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    // 左側：分數圓圈
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$score',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scoreColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 中間：文章標題與時間
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 右側：獲得點數
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('獲得獎勵', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('+$points', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.orange)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        }
      ),
    );
  }
}
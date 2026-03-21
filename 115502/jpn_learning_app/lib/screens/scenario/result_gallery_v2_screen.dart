import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';

class ResultGalleryV2Screen extends StatelessWidget {
  const ResultGalleryV2Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 取得資料庫/Provider 中的單字紀錄
    final scenarios = FavoritesDataProvider.allFavorites;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '我的單字探險',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: scenarios.isEmpty
          ? const Center(
              child: Text(
                '還沒有收藏任何場景喔！',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scenarios.length,
              itemBuilder: (context, index) {
                final scenario = scenarios[index];

                return GestureDetector(
                  onTap: () {
                    // 🌟 點擊後從底部滑出該場景的單字列表
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (context) {
                        // 這裡我們先用假單字陣列模擬，之後可以根據 scenario.title 從資料庫抓對應的單字
                        List<String> vocabList = [];
                        if (scenario.title == '一蘭拉麵店') {
                          vocabList = [
                            'ラーメン (拉麵)',
                            'メニュー (菜單)',
                            'お会計 (結帳)',
                            'おいしい (好吃)',
                          ];
                        } else if (scenario.title == '新宿車站') {
                          vocabList = [
                            'でんしゃ (電車)',
                            'きっぷ (車票)',
                            'のりば (月台)',
                            'まよい (迷路)',
                          ];
                        } else {
                          vocabList = ['おみくじ (御神籤)', 'おまもり (御守)', 'かみさま (神明)'];
                        }

                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 讓高度隨內容自動調整
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${scenario.title} 的單字',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context), // 點擊叉叉關閉
                                  ),
                                ],
                              ),
                              const Divider(), // 分隔線
                              const SizedBox(height: 8),
                              // 動態產生單字列表
                              ...vocabList
                                  .map(
                                    (vocab) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline,
                                            color: AppColors.accentGreen,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            vocab,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

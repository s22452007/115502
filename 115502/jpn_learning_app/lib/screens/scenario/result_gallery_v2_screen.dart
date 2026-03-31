import 'package:flutter/material.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';

// 2. 匯入你要跳轉的相簿詳細頁面
import 'package:jpn_learning_app/screens/profile/album_detail_screen.dart'; 

class ResultGalleryV2Screen extends StatelessWidget {
  const ResultGalleryV2Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 取得資料庫中的場景紀錄
    final scenarios = FavoritesDataProvider.allFavorites;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 或是 AppColors.background
      appBar: AppBar(
        title: const Text(
          '我的單字探險',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                  // ==========================================
                  // 點擊後直接跳轉到「詳細相簿網格」
                  // ==========================================
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumDetailScreen(scenario: scenario),
                      ),
                    );
                  },
                  // ==========================================
                  // 卡片精美 UI 設計 (完全保留你的巧思)
                  // ==========================================
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
                        // 左側：圓形圖片或 Icon
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: scenario.image != null
                              ? ClipOval(
                                  child: Image.asset(
                                    scenario.image!,
                                    fit: BoxFit.cover,
                                    width: 50,
                                    height: 50,
                                  ),
                                )
                              : const Icon(Icons.ramen_dining, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        
                        // 中間：標題與提示文字
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scenario.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '點擊查看詳細單字 >',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        
                        // 右側：日期 (直接抓取 scenario 資料庫裡的日期，更精準！)
                        Text(
                          scenario.date,
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
            ),
    );
  }
}
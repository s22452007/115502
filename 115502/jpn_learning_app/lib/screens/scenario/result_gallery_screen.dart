import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 🌟 已經幫你把會報錯的第 4 行刪掉了！
import 'package:jpn_learning_app/providers/favorites_data.dart';

class ResultGalleryScreen extends StatelessWidget {
  const ResultGalleryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          ? const Center(child: Text('還沒有收藏任何場景喔！'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scenarios.length,
              itemBuilder: (context, index) {
                final scenario = scenarios[index];

                // 🌟 直接在這裡手刻精美卡片，不再依賴外部檔案！
                // 🌟 使用 GestureDetector 來保留點擊功能
                return GestureDetector(
                  onTap: () {
                    // 之後這裡可以連動到你的單字詳細頁面！
                    print('點擊了：${scenario.title}');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(
                      16,
                    ), // 把原本 ListTile 的 padding 移到這裡
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade100,
                      ), // 加上淡淡的邊框增加質感
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03), // 陰影調淡一點更現代
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),

                    // 🌟 這裡開始是全新的自訂 Row 排版
                    child: Row(
                      children: [
                        // 1. 左側：圖片或 Icon 圓框 (取代原本的方形)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter.withOpacity(0.4),
                            shape: BoxShape.circle, // 變成完美的圓形
                          ),
                          alignment: Alignment.center,
                          child: scenario.image != null
                              ? ClipOval(
                                  // 如果有圖片，把它裁切成圓形
                                  child: Image.asset(
                                    scenario.image!,
                                    fit: BoxFit.cover,
                                    width: 50,
                                    height: 50,
                                  ),
                                )
                              : const Icon(
                                  Icons.ramen_dining, // 沒有圖片時的預設圖示
                                  color: AppColors.primary,
                                ),
                        ),
                        const SizedBox(width: 16), // 圓框跟文字的間距
                        // 2. 中間：標題與副標題
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
                              // 因為你目前的 scenario 模型可能還沒有 kana(平假名) 等欄位，我們先用引導文字
                              Text(
                                '點擊查看詳細單字 >',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. 右側：日期
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

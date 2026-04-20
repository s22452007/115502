import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 2. 匯入跳轉的相簿詳細頁面
import 'package:jpn_learning_app/screens/scenario/scenario_detail_screen.dart';

class ResultGalleryV2Screen extends StatelessWidget {
  const ResultGalleryV2Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
      // 加入防呆：如果沒登入就擋下來
      body: userId == null
          ? const Center(child: Text('請先登入才能查看單字探險喔！', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : FutureBuilder<List<dynamic>>(
              // 傳入 limit: 999 這樣就能把所有場景都撈出來，不受首頁只撈3個的限制
              future: ApiClient.getUnlockedScenes(userId, limit: 999),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // 把錯誤訊息印在編輯器的終端機裡
                  debugPrint('取得單字探險發生錯誤: ${snapshot.error}'); 
                  
                  // 並且也顯示在手機畫面上，方便我們看
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('載入失敗原因：\n${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }

                final scenarios = snapshot.data ?? [];

                if (scenarios.isEmpty) {
                  return const Center(
                    child: Text(
                      '還沒有解鎖任何場景喔！\n趕快去拍照探索吧！',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) {
                    final scene = scenarios[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // 把整個 scene 的 Map 傳給詳細頁面
                            builder: (context) => ScenarioDetailScreen(scene: scene),
                          ),
                        );
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
                                                const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
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
                                      Expanded(
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
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _showRenameDialog(
                                              context,
                                              scene['photo_id'],
                                              scene['scene_name'],
                                            );
                                          },
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
              },
            ),
    );
  }
}

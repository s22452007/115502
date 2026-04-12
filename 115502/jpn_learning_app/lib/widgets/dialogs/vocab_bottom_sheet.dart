/// 單字解鎖進度底部表單
/// 負責顯示特定照片/場景中所有單字的解鎖狀態
/// 完美支援 Web 滑鼠拉動與 Mobile 觸控拉動
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

/// 單字底部表單類別
/// 提供靜態方法來顯示場景單字的解鎖進度
class VocabBottomSheet {
  /// 顯示單字解鎖進度底部表單
  /// @param context 建構函式上下文
  /// @param scene 場景資料，包含 scene_name 和 scene_id
  /// @param userId 用戶 ID，如果為 null 則提示登入
  static void show(BuildContext context, dynamic scene, String? userId) {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能查看單字解鎖進度喔！')),
      );
      return;
    }

    final textColor = const Color(0xFF333333);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          // 不要寫死 0.5，讓它自動適應內容，最高不超過 0.9
          initialChildSize: 0.5, 
          minChildSize: 0.3,
          maxChildSize: 0.9,
          // 為了讓高度更貼合內容，我們等一下用 shrinkWrap
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    // 讓這個區域可以接收垂直拖曳事件
                    onVerticalDragUpdate: (details) {
                      // 把拖曳的距離轉換為對 Controller 的滾動，藉此拉動 Sheet
                      scrollController.jumpTo(scrollController.offset - details.primaryDelta!);
                    },
                    child: Container(
                      color: Colors.transparent, // 擴大感應區
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 40, height: 5,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  
                  // ==========================================
                  // 標題列
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('此場景的單字圖鑑', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  const Divider(),
                  
                  // ==========================================
                  // 下方單字列表
                  // ==========================================
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: ApiClient.getVocabsByPhoto(scene['image_path'], int.parse(userId)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text("載入單字失敗"));
                        }

                        final vocabs = snapshot.data ?? [];
                        if (vocabs.isEmpty) {
                          return const Center(child: Text("這個場景還沒有單字喔！"));
                        }

                        // Web 版為了支援滑鼠滾輪，可以加上這個屬性
                        return ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                          ),
                          child: ListView.builder(
                            controller: scrollController,
                            // 讓 ListView 的高度剛好包住內容，不會有多餘空白
                            shrinkWrap: true, 
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                            itemCount: vocabs.length,
                            itemBuilder: (context, index) {
                              final vocab = vocabs[index];
                              final isUnlocked = vocab['is_unlocked'] == true;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${vocab['word']} (${vocab['meaning']})',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isUnlocked ? textColor : Colors.grey.shade500
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
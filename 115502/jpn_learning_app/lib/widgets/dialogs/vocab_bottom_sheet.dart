/// 單字解鎖進度底部表單
/// 負責顯示特定場景中所有單字的解鎖狀態
/// 以底部滑出表單形式展示，用戶可以查看哪些單字已解鎖
import 'package:flutter/material.dart';
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${scene['scene_name']} 的單字', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: FutureBuilder<List<dynamic>>(
                future: ApiClient.getSceneVocabs(scene['scene_id'], int.parse(userId)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("載入單字失敗"));
                    }

                    final vocabs = snapshot.data ?? [];
                    if (vocabs.isEmpty) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("這個場景還沒有單字喔！")));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: vocabs.length,
                      itemBuilder: (context, index) {
                        final vocab = vocabs[index];
                        final isUnlocked = vocab['is_unlocked'] == true;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                isUnlocked ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isUnlocked ? const Color(0xFF6AA86B) : Colors.grey.shade400
                              ),
                              const SizedBox(width: 16),
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
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
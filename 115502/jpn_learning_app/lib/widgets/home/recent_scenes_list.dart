import 'package:flutter/material.dart';

/// 最近解鎖場景列表組件
/// 顯示用戶最近解鎖的場景，支援橫向滾動和點擊查看單字進度
class RecentScenesList extends StatelessWidget {
  /// 最近解鎖的場景資料列表
  final List<dynamic> recentScenes;

  /// 是否正在載入場景資料
  final bool isLoadingScenes;

  /// 點擊場景時的回調函式，用於顯示單字底部表單
  final void Function(dynamic) onShowVocabularyBottomSheet;

  /// 建構子
  const RecentScenesList({
    Key? key,
    required this.recentScenes,
    required this.isLoadingScenes,
    required this.onShowVocabularyBottomSheet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 這是用來強制重新整理快取的註解
    if (isLoadingScenes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (recentScenes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("還沒有解鎖的場景，趕快去拍照探索吧！", style: TextStyle(color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(recentScenes.length, (index) {
            final scene = recentScenes[index];
            final isEven = index % 2 == 0;

            return GestureDetector(
              onTap: () => onShowVocabularyBottomSheet(scene),
              child: Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEven
                      ? const Color(0xFFEBE8F2)
                      : const Color(0xFFEAF4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isEven
                            ? const Color(0xFF8B6B9E)
                            : const Color(0xFF7FAFD0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.train,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scene['scene_name'] ?? '未知場景',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${scene['unlocked_at']} • ${scene['vocab_count']}個單字',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

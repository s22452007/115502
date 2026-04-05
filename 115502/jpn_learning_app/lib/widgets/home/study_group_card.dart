/// 學習小組動態卡片 Widget
/// 負責顯示學習小組中的動態資訊，例如其他用戶獲得的徽章
/// 這個卡片目前顯示靜態範例資料，未來可以從 API 獲取真實的群組動態
import 'package:flutter/material.dart';

/// 學習小組動態卡片組件
/// 顯示群組成員的學習成就，例如獲得徽章的通知
class StudyGroupCard extends StatelessWidget {
  /// 建構子
  /// 不需要額外參數，目前顯示固定的範例資料
  const StudyGroupCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subTextColor = const Color(0xFF888888);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.amber.shade100,
            child: const Text('D', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Din', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('獲得了「麵食大師」徽章', style: TextStyle(fontSize: 13, color: subTextColor)),
              ],
            ),
          ),
          Text('10m', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
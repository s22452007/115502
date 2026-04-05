/// 狀態晶片 Widget
/// 負責顯示用戶狀態的小型資訊卡片，例如學習天數、J-Pts 數量等
/// 使用圖示和文字組合，搭配不同顏色來區分不同類型的狀態
import 'package:flutter/material.dart';

/// 狀態資訊晶片組件
/// 顯示用戶的各種狀態資訊，如連續學習天數、點數餘額等
class StatusChip extends StatelessWidget {
  /// 顯示的圖示
  final IconData icon;

  /// 圖示顏色
  final Color iconColor;

  /// 顯示的文字內容
  final String text;

  /// 邊框顏色
  final Color borderColor;

  /// 建構子
  /// @param icon 要顯示的圖示
  /// @param iconColor 圖示顏色
  /// @param text 顯示的文字
  /// @param borderColor 邊框顏色
  const StatusChip({Key? key, required this.icon, required this.iconColor, required this.text, required this.borderColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(20), color: Colors.white),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        // 🌟 扁平化設計：移除厚重的陰影，只保留極淡的頂部分隔線
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: SafeArea(
        // SafeArea 確保在 iPhone 等有底部橫條的手機上不會被遮擋
        child: SizedBox(
          height: 65, // 導航列基礎高度
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 順序已調整：主頁在最左邊 (Index 0)
              _buildNavItem(0, Icons.home_rounded, '主頁'),
              _buildNavItem(1, Icons.camera_alt_rounded, '相機'),
              _buildNavItem(2, Icons.search_rounded, '搜尋'),
              _buildNavItem(3, Icons.history_rounded, '紀錄'),
              _buildNavItem(4, Icons.person_rounded, '個人'),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 客製化的動畫按鈕
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque, // 確保空白處也能點擊
      child: SizedBox(
        width: 60,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack, // 加入微 Q 彈的動畫曲線
          // 🌟 動畫核心：選中時 Y 軸往上移動 6 pixels
          transform: Matrix4.translationValues(0, isSelected ? -6.0 : 0.0, 0), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌟 圖示放大動畫
              AnimatedScale(
                scale: isSelected ? 1.3 : 1.0, // 選中時放大 1.3 倍
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              // 文字漸變與加粗動畫
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
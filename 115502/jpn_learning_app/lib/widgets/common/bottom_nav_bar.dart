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
    // 🌟 使用 Padding 或 Margin 讓導航欄不貼齊邊緣，產生懸浮感
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 30), // 左右外距 24，底部距離螢幕 30
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        // 🌟 橢圓形核心：設置非常大的圓角
        borderRadius: BorderRadius.circular(40), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // 稍微明顯一點的陰影，增強懸浮層次
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, '主頁'),
          _buildNavItem(1, Icons.camera_alt_rounded, '相機'),
          _buildNavItem(2, Icons.search_rounded, '搜尋'),
          _buildNavItem(3, Icons.history_rounded, '紀錄'),
          _buildNavItem(4, Icons.person_rounded, '個人'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut, // Q 彈曲線
          // 🌟 點擊時往上移動 12 單位，範圍更大
          transform: Matrix4.translationValues(0, isSelected ? -12.0 : 0.0, 0), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.3 : 1.0, // 放大倍數稍微增加
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  child: Icon(
                    icon,
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // 如果導航欄高度有限，可以考慮只在選中時顯示文字，或保持文字小而精緻
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
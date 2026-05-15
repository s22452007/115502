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
      // 🌟 讓底部導航欄上方帶有大幅度圓角
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 75, 
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
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut, // 🌟 更圓潤 Q 彈的曲線
          transform: Matrix4.translationValues(0, isSelected ? -10.0 : 0.0, 0), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌟 選中時背景有一個淡色的小圓圈感
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 400),
                  child: Icon(
                    icon,
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  fontSize: 11,
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
import 'package:flutter/material.dart';

class DifficultyButton extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int rewardPoints;
  final Color activeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const DifficultyButton({
    Key? key,
    required this.label,
    required this.value,
    required this.unit,
    required this.rewardPoints,
    required this.activeColor,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack, // 加入 Q 彈的動畫曲線
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF5F6F8), // 未選中時改用帶點藍灰的高級灰
          borderRadius: BorderRadius.circular(20), // 圓角加大，更現代
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800, // 標題加粗
                color: isSelected ? Colors.white : const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white.withOpacity(0.8) : const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 14), // 拉開一點呼吸空間
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                // 選中時用「黑色微透明」壓暗底色，對比度更好；未選中時用極淡的橘黃色
                color: isSelected ? Colors.black.withOpacity(0.12) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stars_rounded, // 拔掉 Emoji，改用清爽的金幣/星星 Icon
                    size: 14,
                    color: isSelected ? Colors.yellowAccent.shade100 : Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+$rewardPoints 點', // 加上 "+" 號更有獲得感
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
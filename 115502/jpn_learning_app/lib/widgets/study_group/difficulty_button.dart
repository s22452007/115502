import 'package:flutter/material.dart';

class DifficultyButton extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int rewardPoints; // 用來接收獎勵點數
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 8),
            // 超吸睛的獎勵標籤！
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.25) : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🏆 $rewardPoints 點',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.amber.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
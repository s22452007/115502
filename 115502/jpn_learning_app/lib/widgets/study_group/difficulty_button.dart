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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut, 
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeColor.withOpacity(0.35) : Colors.transparent,
              blurRadius: isSelected ? 12 : 0,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
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
            const SizedBox(height: 14),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withOpacity(0.12) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stars_rounded, 
                    size: 14,
                    color: isSelected ? Colors.yellowAccent.shade100 : Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+$rewardPoints 點', 
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
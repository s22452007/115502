import 'package:flutter/material.dart';

class DifficultyButton extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final Color activeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const DifficultyButton({
    Key? key,
    required this.label,
    required this.value,
    required this.unit,
    required this.activeColor,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF333333);
    const Color subTextColor = Color(0xFF888888);
    const Color cardColor = Color(0xFFF9F9F9);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
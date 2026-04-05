import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color borderColor;

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
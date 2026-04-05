import 'package:flutter/material.dart';

class StudyGroupCard extends StatelessWidget {
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
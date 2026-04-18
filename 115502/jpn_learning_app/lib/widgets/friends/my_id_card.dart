import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyIdCard extends StatelessWidget {
  final String myId;
  const MyIdCard({Key? key, required this.myId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color darkGreen = const Color(0xFF4A7A4D);
    final Color lightGreen = const Color(0xFFBFE1C3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightGreen),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的專屬 ID', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(myId, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: darkGreen)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.black54),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: myId));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID 已複製到剪貼簿！📋'), behavior: SnackBarBehavior.floating));
                },
              ),
              IconButton(icon: Icon(Icons.qr_code, color: darkGreen), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
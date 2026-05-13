import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _textColor = const Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _flatCanvasColor, // 🌟 Commit 1: 統一畫布底色
      elevation: 0,
      child: Column(
        children: [
          const SizedBox(height: 100), // 預留 Header 空間
          const Spacer(),
        ],
      ),
    );
  }
}
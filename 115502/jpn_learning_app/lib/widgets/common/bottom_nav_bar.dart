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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      // 🌟 調整順序：主頁移到最左邊 (Index 0)
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '主頁'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: '相機'),
        BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: '搜尋'),
        BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: '紀錄'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: '個人'),
      ],
    );
  }
}
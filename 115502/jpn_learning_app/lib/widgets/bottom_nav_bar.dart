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
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.white,
        unselectedItemColor: AppColors.primaryLighter,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            label: '相機',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '搜尋'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: '學習小組',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '個人檔案',
          ),
        ],
      ),
    );
  }
}

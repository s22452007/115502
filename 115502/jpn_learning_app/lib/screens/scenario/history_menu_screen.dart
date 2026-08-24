import 'package:flutter/material.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/screens/scenario/result_gallery_v2_screen.dart';
import 'package:jpn_learning_app/screens/scenario/chat_history_screen.dart';

/// 「紀錄」選單頁：讓使用者選擇要查看哪一種學習紀錄。
class HistoryMenuScreen extends StatelessWidget {
  const HistoryMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SubPageTemplate(
      title: '學習紀錄',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildEntry(
            context,
            icon: Icons.photo_camera_rounded,
            iconColor: AppColors.primary,
            title: '我的單字探險',
            subtitle: '回顧拍過的照片與解鎖的單字',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResultGalleryV2Screen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildEntry(
            context,
            icon: Icons.forum_rounded,
            iconColor: const Color(0xFF8B6B9E),
            title: 'AI 對話紀錄',
            subtitle: '回顧練習過的對話，也可以接續聊下去',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

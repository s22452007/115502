import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class InvitesStatusCard extends StatelessWidget {
  final int invitesCount;
  final VoidCallback onTap;

  const InvitesStatusCard({
    Key? key,
    required this.invitesCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);

    // 情況 A：沒有邀請，顯示灰色狀態
    if (invitesCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            '目前沒有收到任何邀請喔！',
            style: TextStyle(
              fontSize: 15,
              color: subText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // 情況 B：有邀請，顯示黃色可點擊卡片
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(),  #0xFFF6EBC7
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: Text(
                '$invitesCount',
                style: const TextStyle(color: Color(0xFF4E8B4C), fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('你有待處理的邀請', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                  const SizedBox(height: 4),
                  Text('點擊查看誰邀請了你進入小組', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
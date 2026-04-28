import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class RulesCard extends StatelessWidget {
  const RulesCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                '生存法則與對賭機制',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF333333)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRuleRow(Icons.calendar_today_rounded, '一週為限', '小組以週為單位，每週日 23:59 自動結算。'),
          const SizedBox(height: 12),
          _buildRuleRow(Icons.lock_outline_rounded, '鎖定防逃', '一旦建立或加入，結算前「絕對無法」退出。'),
          const SizedBox(height: 12),
          _buildRuleRow(Icons.monetization_on_outlined, '押金機制', '每週首次加入免費！第 2 次起需付 20 點押金。'),
          const SizedBox(height: 12),
          _buildRuleRow(Icons.card_giftcard_rounded, '各自結業', '達標後可隨時領獎、退押金並結業；失敗則沒收。'),
        ],
      ),
    );
  }

  // 輔助生成規則文字的 UI 積木 (放在這個 class 裡面即可)
  Widget _buildRuleRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6E6E6E)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.4),
              children: [
                TextSpan(text: '[$title] ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class EmptyGroupBanner extends StatelessWidget {
  const EmptyGroupBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF333333);
    const Color subText = Color(0xFF6E6E6E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_rounded,
            size: 74,
            color: AppColors.primaryLighter,
          ),
          const SizedBox(height: 16),
          const Text(
            '你目前還沒有加入任何學習小組',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '和好友一起累積 points，學習更有動力',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: subText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
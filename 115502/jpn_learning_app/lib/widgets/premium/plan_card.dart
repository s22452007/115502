import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class PlanCard extends StatelessWidget {
  final String title;
  final bool isPro;
  final bool isCurrent;
  final String priceText;
  final String? subtitle;
  final String? badgeText;
  final List<String> features;
  final String? btnText;
  final String? btnSubText;
  final Color? btnColor;
  final VoidCallback? onTap;
  final bool isScheduledUpgrade;
  final String? scheduledDate;

  const PlanCard({
    Key? key,
    required this.title,
    required this.isPro,
    required this.isCurrent,
    required this.priceText,
    required this.features,
    this.subtitle,
    this.badgeText,
    this.btnText,
    this.btnSubText,
    this.btnColor,
    this.onTap,
    this.isScheduledUpgrade = false,
    this.scheduledDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleColor = isPro ? AppColors.secondary : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: titleColor, width: isPro ? 2 : 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPro) const Icon(Icons.workspace_premium, color: AppColors.secondary, size: 24),
              if (isPro) const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardGold,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(priceText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning)),
          ],
          const SizedBox(height: 12),
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(isPro ? Icons.check_circle : Icons.check, color: isPro ? AppColors.primary : Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(feature, style: const TextStyle(color: AppColors.textGrey, height: 1.4)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          if (isScheduledUpgrade) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✓ 已排程升級至年繳',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        if (scheduledDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '將於 $scheduledDate 自動切換',
                            style: const TextStyle(color: AppColors.primary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (btnText != null && btnText!.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent ? Colors.grey.shade300 : (btnColor ?? const Color(0xFF4E8B4C)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isCurrent ? null : onTap,
                child: Text(
                  btnText!,
                  style: TextStyle(
                    color: isCurrent ? Colors.black54 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (btnSubText != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  btnSubText!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

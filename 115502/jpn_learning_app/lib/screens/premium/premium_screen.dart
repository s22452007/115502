import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_trial_screen.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  static const Color _green = Color(0xFF4E8B4C);
  static const Color _lightGreen = Color(0xFF95BE94);
  static const Color _premiumGold = Color(0xFFC6B13B);
  static const Color _textDark = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 24, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Upgrade to Premium',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 18),

              _PlanCard(
                title: 'Free',
                titleColor: _green,
                actionText: '開始使用',
                priceText: '\$ 0/月',
                features: const [
                  '每 10 分鐘觀看一次廣告',
                  '每日最多 3 次 AI 對話',
                  '每日最多 3 次場景照片上傳',
                  '基本學習結果',
                ],
                actionColor: _lightGreen,
                onActionTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),

              const SizedBox(height: 16),

              // 購買點數入口
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuyPointsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0C85C)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined, color: Color(0xFFC6A700), size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '購買 J-Pts 點數',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '用點數解鎖更多學習功能',
                              style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFC6A700)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _PlanCard(
                title: 'Premium Pro',
                titleColor: _green,
                actionText: '免費試用',
                priceText: '\$ 490/月  \$ 1280/年',
                features: const [
                  '無限使用，免廣告',
                  '無限次 AI 對話、場景照片上傳',
                  '詳細學習分析報告',
                  '每月贈送 1000 Points',
                ],
                actionColor: _lightGreen,
                showCrown: true,
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PremiumTrialScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final Color titleColor;
  final String actionText;
  final String priceText;
  final List<String> features;
  final Color actionColor;
  final bool showCrown;
  final VoidCallback? onActionTap;

  const _PlanCard({
    required this.title,
    required this.titleColor,
    required this.actionText,
    required this.priceText,
    required this.features,
    required this.actionColor,
    this.showCrown = false,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PremiumScreen._green, width: 1.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showCrown) ...[
                const Icon(
                  Icons.workspace_premium,
                  size: 20,
                  color: PremiumScreen._premiumGold,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onActionTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            priceText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PremiumScreen._textDark,
            ),
          ),
          const SizedBox(height: 14),
          ...features.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: PremiumScreen._textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
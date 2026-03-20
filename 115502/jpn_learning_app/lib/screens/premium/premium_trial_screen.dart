import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class PremiumTrialScreen extends StatelessWidget {
  const PremiumTrialScreen({Key? key}) : super(key: key);

  static const Color bgColor = Colors.white;
  static const Color green = Color(0xFF4E8B4C);
  static const Color lightGreen = Color(0xFFEFF5EA);
  static const Color softGreen = Color(0xFF95BE94);
  static const Color gold = Color(0xFFC6B13B);
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF666666);
  static const Color beige = Color(0xFFFCF6EA);
  static const Color borderGreen = Color(0xFFA9C5A8);

  @override
  Widget build(BuildContext context) {
    final DateTime trialEnd = DateTime.now().add(const Duration(days: 7));
    final String trialEndText =
        '${trialEnd.year}/${trialEnd.month.toString().padLeft(2, '0')}/${trialEnd.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 18),
                    _buildHeroCard(),
                    const SizedBox(height: 18),
                    _buildTrialInfoCard(trialEndText),
                    const SizedBox(height: 18),
                    _buildPaymentCard(),
                  ],
                ),
              ),
            ),
            _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: green,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            '開始免費試用',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.close,
            color: Colors.black45,
            size: 34,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderGreen, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFFFD76A),
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Pro',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '免費試用 7 天',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _featureRow('無限 AI 對話'),
          const SizedBox(height: 14),
          _featureRow('無限場景照片上傳'),
          const SizedBox(height: 14),
          _featureRow('詳細學習分析報告'),
          const SizedBox(height: 14),
          _featureRow('每月贈送 1000 Points'),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '試用結束後將自動續訂 \$490/月，可隨時取消',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialInfoCard(String trialEndText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: beige,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '試用說明',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 18),
          _featureRow('免費試用期至：$trialEndText', darkCheck: true),
          const SizedBox(height: 14),
          _featureRow('到期日前可隨時取消', darkCheck: true),
          const SizedBox(height: 14),
          _featureRow('若未取消，將自動續訂月費方案', darkCheck: true),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E7D7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '付款方式',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E8DD)),
            ),
            child: const Row(
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  'Google Play',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Visa ••••• 1234',
                    style: TextStyle(
                      fontSize: 16,
                      color: textDark,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: () {
              _showTrialSuccessDialog(context);
            },
            child: const Text(
              '開始 7 天免費試用',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow(String text, {bool darkCheck = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_rounded,
          size: 34,
          color: darkCheck ? green : green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }

  void _showTrialSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            '免費試用已啟用',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          content: const Text(
            '你現在可以開始使用 Premium Pro 的完整功能。',
            style: TextStyle(
              color: subText,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                '開始使用',
                style: TextStyle(
                  color: green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
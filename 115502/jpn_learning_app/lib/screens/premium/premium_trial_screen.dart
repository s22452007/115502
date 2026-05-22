import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class PremiumTrialScreen extends StatefulWidget {
  final int priceMonthly;

  const PremiumTrialScreen({Key? key, this.priceMonthly = 99}) : super(key: key);

  @override
  State<PremiumTrialScreen> createState() => _PremiumTrialScreenState();
}

class _PremiumTrialScreenState extends State<PremiumTrialScreen> {
  static const Color bgColor = Colors.white;
  static const Color green = Color(0xFF4E8B4C);
  static const Color lightGreen = Color(0xFFEFF5EA);
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF666666);
  static const Color beige = Color(0xFFFCF6EA);
  static const Color borderGreen = Color(0xFFA9C5A8);

  String _paymentMethod = 'google_pay';
  bool _isProcessing = false;

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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 14),
                    _buildHeroCard(),
                    const SizedBox(height: 14),
                    _buildTrialInfoCard(trialEndText),
                    const SizedBox(height: 14),
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
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: green, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '開始免費試用',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderGreen, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD76A), size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
                    SizedBox(height: 4),
                    Text('免費試用 7 天', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _featureRow('每日 10 次 AI 對話'),
          const SizedBox(height: 10),
          _featureRow('每日 10 次場景照片上傳'),
          const SizedBox(height: 10),
          _featureRow('詳細學習分析報告'),
          const SizedBox(height: 10),
          _featureRow('每月贈送點數'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(16)),
            child: Text(
              '試用結束後將自動續訂 NT\$${widget.priceMonthly}/月，可隨時取消',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialInfoCard(String trialEndText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(color: beige, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('試用說明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 14),
          _featureRow('免費試用期至：$trialEndText', darkCheck: true),
          const SizedBox(height: 10),
          _featureRow('到期日前可隨時取消', darkCheck: true),
          const SizedBox(height: 10),
          _featureRow('若未取消，將自動續訂月費方案', darkCheck: true),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E7D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('付款方式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 12),
          _buildPaymentOption('google_pay', 'Google Pay', Icons.payments_outlined),
          const SizedBox(height: 8),
          _buildPaymentOption('card', '信用卡 / 簽帳金融卡', Icons.credit_card),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700)),
            ),
            child: const Text(
              '💡 正式上線後將支援：\n'
              '✓ Google Pay\n'
              '✓ 信用卡 / 簽帳金融卡（由綠界安全處理）\n\n'
              '目前為 Demo 模式，點擊開始試用將直接模擬成功。',
              style: TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? lightGreen : const Color(0xFFF8FAF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? green : const Color(0xFFE0E8DD), width: isSelected ? 1.5 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              activeColor: green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Icon(icon, color: green, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: textDark, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _isProcessing ? null : () => _handleActivate(context),
            child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text(
                    '開始 7 天免費試用',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleActivate(BuildContext context) async {
    setState(() => _isProcessing = true);

    // 顯示 Loading 對話框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: green,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '試用啟用中...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Demo 模式：模擬 1.5 秒的處理
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    Navigator.pop(context); // 關閉 Loading 對話框

    // await 前先取出 provider 參照，避免跨 async gap 使用 context
    final provider = context.read<UserProvider>();
    final userId = provider.userId;

    if (userId != null) {
      final res = await ApiClient.activatePremium(userId, paymentMethod: _paymentMethod);
      if (!mounted) return;
      if (res['error'] != null) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'].toString())),
        );
        return;
      }
      provider.setIsPremium(true);
      provider.setTrialUsed(true);

      final statusRes = await ApiClient.getSubscriptionStatus(userId);
      if (statusRes.containsKey('subscription') && statusRes['subscription'] != null) {
        final sub = statusRes['subscription'];
        provider.setSubscriptionInfo(
          endDate: sub['end_date'],
          autoRenew: sub['auto_renew'] ?? false,
          status: sub['status'],
          planName: sub['plan_name'],
          billingCycle: sub['billing_cycle'],
        );
      }
      if (statusRes.containsKey('trial_used')) {
        provider.setTrialUsed(statusRes['trial_used'] == true);
      }
      if (statusRes.containsKey('is_premium')) {
        provider.setIsPremium(statusRes['is_premium'] == true);
      }
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showTrialSuccessDialog(context);
  }

  Widget _featureRow(String text, {bool darkCheck = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_rounded, size: 24, color: green),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35, color: textDark))),
      ],
    );
  }

  void _showTrialSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('免費試用已啟用', style: TextStyle(fontWeight: FontWeight.w800, color: textDark)),
        content: const Text(
          '你現在可以開始使用 Premium Pro 的完整功能。',
          style: TextStyle(color: subText, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('開始使用', style: TextStyle(color: green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

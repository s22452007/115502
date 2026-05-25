import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class PremiumTrialScreen extends StatefulWidget {
  final int priceMonthly;

  const PremiumTrialScreen({Key? key, this.priceMonthly = 99}) : super(key: key);

  @override
  State<PremiumTrialScreen> createState() => _PremiumTrialScreenState();
}

class _PremiumTrialScreenState extends State<PremiumTrialScreen> {
  // 🌟 扁平化 UI 參數
  static const Color _bgColor = Color(0xFFF4F7F5);
  static const Color _textDark = Color(0xFF2C3E50);
  static const Color _subText = Color(0xFF8E9AAB);

  String _paymentMethod = 'google_pay';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final DateTime trialEnd = DateTime.now().add(const Duration(days: 7));
    // 假設 formatDate 存在於你的 utils 中，若無請換成簡單日期字串
    final String trialEndText = "${trialEnd.year}/${trialEnd.month}/${trialEnd.day}";

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 24),
                    _buildHeroCard(),
                    const SizedBox(height: 16),
                    _buildTrialInfoCard(trialEndText),
                    const SizedBox(height: 16),
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
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Text(
          '開始免費試用',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Premium Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                  SizedBox(height: 4),
                  Text('免費試用 7 天', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _featureRow('每日 10 次 AI 對話'),
          _featureRow('每日 10 次場景照片上傳'),
          _featureRow('詳細學習分析報告'),
          _featureRow('每月贈送點數'),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
            child: Text(
              '試用結束後將自動續訂 NT\$${widget.priceMonthly}/月，可隨時取消',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialInfoCard(String trialEndText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('試用說明', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
          const SizedBox(height: 16),
          _featureRow('免費試用期至：$trialEndText'),
          _featureRow('到期日前可隨時取消'),
          _featureRow('若未取消，將自動續訂月費方案'),
          _featureRow('訂閱成功後每月贈送 20 J-Pts'),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('付款方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
          const SizedBox(height: 16),
          _buildPaymentOption('google_pay', 'Google Pay', Icons.payments_rounded),
          const SizedBox(height: 12),
          _buildPaymentOption('card', '信用卡 / 簽帳金融卡', Icons.credit_card_rounded),
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
          color: isSelected ? AppColors.primary.withOpacity(0.08) : _bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : _subText, size: 22),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? _textDark : _subText, fontSize: 15)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isProcessing ? null : () => _handleActivate(context),
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('開始 7 天免費試用', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  // 扁平化的功能點 Row
  Widget _featureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // 以下邏輯功能部分維持原樣不變
  Future<void> _handleActivate(BuildContext context) async {
    setState(() => _isProcessing = true);
    final provider = context.read<UserProvider>();
    final userId = provider.userId;

    if (userId != null) {
      final res = await ApiClient.activatePremium(userId, paymentMethod: _paymentMethod);
      if (!mounted) return;
      if (res['error'] != null) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'].toString())));
        return;
      }
      provider.setIsPremium(true);
      provider.setTrialUsed(true);
      final statusRes = await ApiClient.getSubscriptionStatus(userId);
      if (statusRes.containsKey('subscription') && statusRes['subscription'] != null) {
        final sub = statusRes['subscription'];
        provider.setSubscriptionInfo(endDate: sub['end_date'], autoRenew: sub['auto_renew'] ?? false, status: sub['status'], planName: sub['plan_name'], billingCycle: sub['billing_cycle']);
      }
    }
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showTrialSuccessDialog(context);
  }

  void _showTrialSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('免費試用已啟用', style: TextStyle(fontWeight: FontWeight.w900, color: _textDark)),
        content: const Text('你現在可以開始使用 Premium Pro 的完整功能。', style: TextStyle(color: _subText, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
            },
            child: const Text('開始使用', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
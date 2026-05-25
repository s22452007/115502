import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  final int planId;
  final String planName;
  final int priceMonthly;
  final int priceYearly;
  final List<String> features;
  final int pointsGrantMonthly;
  final int pointsGrantYearly;
  final String initialBillingCycle;
  final bool isTrialPurchase;
  final bool isPendingUpgrade;
  final String? pendingUpgradeStart;
  final String? currentSubscriptionEndDate;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
    required this.pointsGrantMonthly,
    required this.pointsGrantYearly,
    required this.initialBillingCycle,
    this.isTrialPurchase = false,
    this.isPendingUpgrade = false,
    this.pendingUpgradeStart,
    this.currentSubscriptionEndDate,
  });

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState extends State<SubscriptionCheckoutScreen> {
  // 🌟 扁平化配色常量
  static const Color _bgColor = Color(0xFFF4F7F5);
  static const Color _textDark = Color(0xFF2C3E50);
  static const Color _subText = Color(0xFF8E9AAB);

  String _paymentMethod = 'google_pay';
  bool _isProcessing = false;

  bool get _isMonthly => widget.initialBillingCycle == 'monthly';
  int get _price => (_isMonthly ? widget.priceMonthly : widget.priceYearly) ?? 0;
  int get _points => (_isMonthly ? widget.pointsGrantMonthly : widget.pointsGrantYearly) ?? 0;
  String get _planTitle => _isMonthly ? 'Premium (月繳)' : 'Premium Pro (年繳)';
  bool get _isTrialFlow => _isMonthly && widget.isTrialPurchase;

  // 輔助函式：日期格式化 (若你的專案有 utils，請確保可呼叫)
  String _formatIsoDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}/${dt.month}/${dt.day}";
    } catch (_) {
      return iso;
    }
  }

  Future<void> _handleConfirm() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final res = widget.isPendingUpgrade
        ? await ApiClient.scheduleYearlyUpgrade(userId, paymentMethod: _paymentMethod)
        : await ApiClient.subscribeplan(
            userId: userId,
            planId: widget.planId,
            billingCycle: widget.initialBillingCycle,
            paymentMethod: _paymentMethod,
          );

    if (!mounted) return;
    if (!res.containsKey('error')) {
      final provider = context.read<UserProvider>();
      if (widget.isPendingUpgrade) {
        if (res['total_points'] != null) provider.setJPts((res['total_points'] as num).toInt());
        provider.setPendingUpgradeStart(res['scheduled_start'] as String?);
      } else {
        provider.setIsPremium(true);
        if (res['total_points'] != null) provider.setJPts((res['total_points'] as num).toInt());
        provider.setSubscriptionInfo(endDate: res['end_date'], autoRenew: true, status: 'active', planName: _planTitle, billingCycle: widget.initialBillingCycle);
      }
      _showSuccessDialog(res);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? '付款失敗')));
    }
  }

  void _showSuccessDialog(Map<String, dynamic> res) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 64),
            const SizedBox(height: 16),
            const Text('付款成功！', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _textDark)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context, true); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('開始使用', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('確認訂閱內容', style: TextStyle(color: _textDark, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 方案卡片
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_planTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
                const SizedBox(height: 8),
                Text('NT\$ $_price / ${_isMonthly ? '月' : '年'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: _textDark)),
                const SizedBox(height: 16),
                ...widget.features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w600))),
                  ]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 提示卡片 (扁平化背景)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFEDF3EF), borderRadius: BorderRadius.circular(20)),
            child: Text(
              _isTrialFlow ? '⭐ 本次訂閱享 7 天免費試用。' : '⭐ 訂閱即享 Premium 完整權益與無限收藏。',
              style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),

          // 付款方式
          const Text('付款方式', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _textDark)),
          const SizedBox(height: 12),
          _buildPaymentOption('google_pay', 'Google Pay', Icons.payments_rounded),
          const SizedBox(height: 12),
          _buildPaymentOption('card', '信用卡', Icons.credit_card_rounded),
          const SizedBox(height: 32),

          // 結帳按鈕 (大氣的扁平化按鈕)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _isTrialFlow ? '確認試用' : '立即支付 NT\$ $_price',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
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
          color: isSelected ? const Color(0xFFEDF3EF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : _subText, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? AppColors.primary : _textDark, fontSize: 16)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
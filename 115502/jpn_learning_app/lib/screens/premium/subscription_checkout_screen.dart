import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  final int planId;
  final String planName;
  final int priceMonthly;
  final int priceYearly;
  final List<String> features;
  final int pointsGrant;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
    required this.pointsGrant,
  });

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  static const _green = Color(0xFF4E8B4C);
  static const _gold = Color(0xFFC6B13B);
  static const _textDark = Color(0xFF333333);
  static const _bg = Color(0xFFF8F8F8);

  String _billingCycle = 'monthly';
  String _paymentMethod = 'google_pay';
  bool _isProcessing = false;

  int get _price =>
      _billingCycle == 'yearly' ? widget.priceYearly : widget.priceMonthly;

  String get _paymentLabel =>
      _paymentMethod == 'card' ? '信用卡' : 'Google Pay';

  Future<void> _handleConfirm() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _isProcessing = true);

    final res = await ApiClient.subscribeplan(
      userId: userId,
      planId: widget.planId,
      billingCycle: _billingCycle,
      paymentMethod: _paymentMethod == 'card' ? '信用卡' : 'Google Pay',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!res.containsKey('error')) {
      final provider = context.read<UserProvider>();
      provider.setIsPremium(true);
      if (res['total_points'] != null) {
        provider.setJPts(res['total_points']);
      }
      provider.setSubscriptionInfo(
        endDate: res['end_date'],
        autoRenew: true,
        status: 'active',
        planName: widget.planName,
        billingCycle: _billingCycle,
      );
      _showSuccessDialog(res);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? '訂閱失敗，請稍後再試')),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> res) {
    String endDateStr = '—';
    if (res['end_date'] != null) {
      try {
        final dt = DateTime.parse(res['end_date']).toLocal();
        endDateStr =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: _green, size: 56),
            SizedBox(height: 8),
            Text('訂閱成功！', textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.planName} 已啟用',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 4),
            Text('有效期至 $endDateStr',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (widget.pointsGrant > 0) ...[
              const SizedBox(height: 8),
              Text('已贈送 ${widget.pointsGrant} J-Points！',
                  style: const TextStyle(color: _gold, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // 回到上一層（PremiumScreen）
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('確認訂閱'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 方案卡
          _PlanCard(name: widget.planName, features: widget.features),
          const SizedBox(height: 20),

          // 計費週期選擇
          _SectionTitle('計費週期'),
          const SizedBox(height: 8),
          _BillingToggle(
            selected: _billingCycle,
            monthlyPrice: widget.priceMonthly,
            yearlyPrice: widget.priceYearly,
            onChanged: (v) => setState(() => _billingCycle = v),
          ),
          const SizedBox(height: 20),

          // 付款方式
          _SectionTitle('付款方式'),
          const SizedBox(height: 8),
          _PaymentSelector(
            selected: _paymentMethod,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          const SizedBox(height: 20),

          // 訂單摘要
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('訂單摘要',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _textDark)),
                const Divider(height: 20),
                _summaryRow(widget.planName,
                    '${_billingCycle == "yearly" ? "年繳" : "月繳"} NT\$$_price'),
                if (widget.pointsGrant > 0)
                  _summaryRow('贈送點數', '${widget.pointsGrant} J-Points',
                      valueColor: _gold),
                _summaryRow('付款方式', _paymentLabel),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 確認按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      '$_paymentLabel  NT\$$_price',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '訂閱後可隨時取消自動續訂，效期至到期日結束。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: valueColor ?? _textDark)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF333333)),
      );
}

class _PlanCard extends StatelessWidget {
  final String name;
  final List<String> features;
  const _PlanCard({required this.name, required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4E8B4C), width: 1.5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified, color: Color(0xFF4E8B4C), size: 24),
            const SizedBox(width: 8),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF333333))),
          ]),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.check, color: Color(0xFF4E8B4C), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF555555)))),
                ]),
              )),
        ],
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final String selected;
  final int monthlyPrice;
  final int yearlyPrice;
  final ValueChanged<String> onChanged;

  const _BillingToggle({
    required this.selected,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _option('monthly', '每月繳費', 'NT\$$monthlyPrice / 月'),
        const SizedBox(height: 8),
        _option('yearly', '每年繳費', 'NT\$$yearlyPrice / 年（省更多）'),
      ],
    );
  }

  Widget _option(String value, String label, String price) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEAF4EA)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF4E8B4C)
                  : const Color(0xFFE0E0E0),
              width: isSelected ? 2 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Radio<String>(
                value: value,
                groupValue: selected,
                onChanged: (v) => onChanged(v!),
                activeColor: const Color(0xFF4E8B4C)),
            const SizedBox(width: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333))),
              Text(price,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF777777))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _option('google_pay', 'Google Pay', Icons.payments_outlined),
        const SizedBox(height: 8),
        _option('card', '信用卡', Icons.credit_card),
      ],
    );
  }

  Widget _option(String value, String label, IconData icon) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF4EA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF4E8B4C)
                  : const Color(0xFFE0E0E0),
              width: isSelected ? 2 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Radio<String>(
                value: value,
                groupValue: selected,
                onChanged: (v) => onChanged(v!),
                activeColor: const Color(0xFF4E8B4C)),
            const SizedBox(width: 4),
            Icon(icon, color: const Color(0xFF4E8B4C), size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }
}

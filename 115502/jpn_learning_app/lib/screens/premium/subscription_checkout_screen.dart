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
  final int pointsGrantMonthly;
  final int pointsGrantYearly;
  final String initialBillingCycle;

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
  });

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState extends State<SubscriptionCheckoutScreen> {
  static const _green = Color(0xFF4E8B4C);
  static const _gold = Color(0xFFC6B13B);
  static const _textDark = Color(0xFF333333);
  static const _bg = Color(0xFFF8F8F8);

  String _paymentMethod = 'google_pay';
  bool _isProcessing = false;

  // 使用 ?? 0 確保就算資料有問題也不會產生紅色毛毛蟲
  bool get _isMonthly => widget.initialBillingCycle == 'monthly';
  int get _price => (_isMonthly ? widget.priceMonthly : widget.priceYearly) ?? 0;
  int get _points => (_isMonthly ? widget.pointsGrantMonthly : widget.pointsGrantYearly) ?? 0;
  
  String get _planTitle => _isMonthly ? 'Premium (月繳)' : 'Premium Pro (年繳)';
  String get _paymentLabel => _paymentMethod == 'card' ? '信用卡' : 'Google Pay';

  Future<void> _handleConfirm() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _isProcessing = true);

    final res = await ApiClient.subscribeplan(
      userId: userId,
      planId: widget.planId,
      billingCycle: widget.initialBillingCycle,
      paymentMethod: _paymentLabel,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!res.containsKey('error')) {
      final provider = context.read<UserProvider>();
      provider.setIsPremium(true);
      if (res['total_points'] != null) {
        provider.setJPts((res['total_points'] as num).toInt());
      }
      provider.setSubscriptionInfo(
        endDate: res['end_date'],
        autoRenew: true,
        status: 'active',
        planName: _planTitle,
        billingCycle: widget.initialBillingCycle,
      );
      _showSuccessDialog(res);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? '訂閱失敗，請稍後再試')),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> res) {
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
            Text('$_planTitle 已啟用', style: const TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
              child: Text('🎁 已贈送 $_points J-Points！', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('開始使用'),
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
      appBar: AppBar(backgroundColor: _green, foregroundColor: Colors.white, title: const Text('確認訂閱內容'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 方案卡
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _isMonthly ? _green : _gold, width: 2)),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_planTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _isMonthly ? _green : _gold)),
                    Text('NT\$ $_price / ${_isMonthly ? '月' : '年'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _textDark)),
                  ],
                ),
                const SizedBox(height: 12),
                ...widget.features.map((f) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(Icons.check_circle, color: _isMonthly ? _green : _gold, size: 18), const SizedBox(width: 8), Expanded(child: Text(f, style: const TextStyle(fontSize: 14, color: Color(0xFF555555)) ))]))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 提示文字 (解決你的 UX 疑慮)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _isMonthly ? const Color(0xFFEAF4EA) : const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12)),
            child: Text(
              _isMonthly 
                ? '⭐ 本次訂閱享 7 天免費試用。\n'
                  '• 試用期內隨時可取消，無需負擔任何費用。\n'
                  '• 若到期未取消，系統將自動按月續訂扣款。'
                : '⚡ 年繳方案享激省優惠。\n'
                  '• 確認訂閱後將立即扣款 NT\$ $_price。\n'
                  '• 隨時可取消自動續訂，效期至一年後結束。',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF555555), height: 1.5),
            ),
          ),
          const SizedBox(height: 24),

          const Text('付款方式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textDark)),
          const SizedBox(height: 8),
          _buildPaymentOption('google_pay', 'Google Pay', Icons.payments_outlined),
          const SizedBox(height: 8),
          _buildPaymentOption('card', '信用卡', Icons.credit_card),
          const SizedBox(height: 24),

          // 訂單摘要
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E0E0))),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('訂單摘要', style: TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
                const Divider(height: 20),
                _summaryRow(_planTitle, 'NT\$ $_price'),
                if (_isMonthly) _summaryRow('首期費用', 'NT\$ 0 (享 7 天免費試用)', valueColor: Colors.green),
                _summaryRow(
                  '🎁 成功訂閱贈送', 
                  _isMonthly ? '+$_points 點 (試用結束後)' : '+$_points 點', 
                  valueColor: _gold
                ),
                _summaryRow('付款方式', _paymentLabel),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('今日結帳總計', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark)),
                    Text(_isMonthly ? 'NT\$ 0' : 'NT\$ $_price', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.redAccent)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(backgroundColor: _isMonthly ? _green : _gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _isProcessing 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_isMonthly ? '同意規則並開始 7 天試用' : '$_paymentLabel  NT\$ $_price', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFEAF4EA) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? _green : const Color(0xFFE0E0E0), width: isSelected ? 2 : 1)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Radio<String>(value: value, groupValue: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v!), activeColor: _green),
            const SizedBox(width: 4),
            Icon(icon, color: _green, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: _textDark, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF777777), fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: valueColor ?? _textDark)),
        ],
      ),
    );
  }
}
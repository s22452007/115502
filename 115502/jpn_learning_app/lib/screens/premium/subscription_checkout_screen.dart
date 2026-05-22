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

  bool get _isTrialFlow => _isMonthly && widget.isTrialPurchase;

  String _formatIsoDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _handleConfirm() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    setState(() => _isProcessing = true);

    // Demo 模式：模擬 1.5 秒的付款處理
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() => _isProcessing = false);

    // 模擬 API 回應
    final res = widget.isPendingUpgrade
        ? await ApiClient.payPendingUpgrade(userId, paymentMethod: _paymentLabel)
        : await ApiClient.subscribeplan(
            userId: userId,
            planId: widget.planId,
            billingCycle: widget.initialBillingCycle,
            paymentMethod: _paymentLabel,
          );

    if (!mounted) return;

    if (!res.containsKey('error')) {
      final provider = context.read<UserProvider>();
      if (!widget.isPendingUpgrade) {
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
      } else {
        final statusRes = await ApiClient.getSubscriptionStatus(userId);
        if (!mounted) return;
        if (statusRes.containsKey('is_premium')) {
          provider.setIsPremium(statusRes['is_premium'] == true);
        }
        if (statusRes.containsKey('trial_used')) {
          provider.setTrialUsed(statusRes['trial_used'] == true);
        }
        final sub = statusRes['subscription'];
        if (sub != null) {
          provider.setSubscriptionInfo(
            endDate: sub['end_date'],
            autoRenew: sub['auto_renew'] ?? false,
            status: sub['status'],
            planName: sub['plan_name'],
            billingCycle: sub['billing_cycle'],
          );
        }
      }
      _showSuccessDialog(res);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? '付款失敗，請稍後再試')),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> res) {
    final titleText = widget.isPendingUpgrade ? '付款成功！' : '訂閱成功！';
    final messageText = widget.isPendingUpgrade
        ? '年繳升級排程付款已完成，系統將依排程時間啟動年繳方案。'
        : '$_planTitle 已啟用';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: _green, size: 56),
            const SizedBox(height: 8),
            Text(titleText, textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(messageText, style: const TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 12),
            if (!widget.isPendingUpgrade)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                child: Text('🎁 已贈送 $_points J-Points！', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFEAF4EA), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  widget.pendingUpgradeStart != null
                      ? '排程啟用日：${_formatIsoDate(widget.pendingUpgradeStart)}'
                      : '排程年繳將依預定時間啟用。',
                  style: const TextStyle(color: _green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
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
              widget.isPendingUpgrade
                  ? '⚡ 這是年繳升級排程付款。付款後將依預定時間啟用年繳方案。當前方案效期至 ${_formatIsoDate(widget.currentSubscriptionEndDate)}。'
                  : (_isTrialFlow
                      ? '⭐ 本次訂閱享 7 天免費試用。\n'
                        '• 試用期內隨時可取消，無需負擔任何費用。\n'
                        '• 若到期未取消，系統將自動按月續訂扣款。'
                      : (_isMonthly
                          ? '⭐ 選擇月繳方案，訂閱將立即啟動並於每月自動續訂。'
                          : '⚡ 年繳方案享激省優惠。\n'
                            '• 確認訂閱後將立即扣款 NT\$ $_price。\n'
                            '• 隨時可取消自動續訂，效期至一年後結束。')),
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF555555), height: 1.5),
            ),
          ),
          const SizedBox(height: 24),

          const Text('付款方式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textDark)),
          const SizedBox(height: 8),
          _buildPaymentOption('google_pay', 'Google Pay', Icons.payments_outlined),
          const SizedBox(height: 8),
          _buildPaymentOption('card', '信用卡', Icons.credit_card),
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
              '目前為 Demo 模式，點擊付款將直接模擬成功。',
              style: TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.4),
            ),
          ),
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
                if (_isTrialFlow) _summaryRow('首期費用', 'NT\$ 0 (享 7 天免費試用)', valueColor: Colors.green),
                if (_isMonthly && !_isTrialFlow) _summaryRow('首期費用', 'NT\$ $_price', valueColor: Colors.black),
                _summaryRow(
                  '🎁 成功訂閱贈送', 
                  _isMonthly
                      ? (_isTrialFlow ? '+$_points 點 (試用結束後)' : '+$_points 點')
                      : '+$_points 點', 
                  valueColor: _gold
                ),
                _summaryRow('付款方式', _paymentLabel),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('今日結帳總計', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark)),
                    Text(_isTrialFlow ? 'NT\$ 0' : 'NT\$ $_price', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.redAccent)),
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
                : Text(
                    _isTrialFlow
              ? '同意規則並開始 7 天試用'
              : (widget.isPendingUpgrade ? '確認付款' : (_isMonthly ? '立即訂閱月繳' : '$_paymentLabel  NT\$ $_price')),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
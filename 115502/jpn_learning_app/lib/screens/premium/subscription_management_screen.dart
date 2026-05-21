import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
import 'package:jpn_learning_app/screens/premium/subscription_checkout_screen.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  static const _green = Color(0xFF4E8B4C);
  static const _gold = Color(0xFFC6B13B);
  static const _textDark = Color(0xFF333333);

  bool _isLoading = true;
  bool _isSubscribed = false;
  bool _isCancelling = false;
  bool _isScheduling = false;

  String? _planName;
  String? _billingCycle;
  String? _endDate;
  bool _autoRenew = false;
  String? _status;
  String? _pendingUpgradeStart;
  String? _pendingPaymentStatus;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final res = await ApiClient.getSubscriptionStatus(userId);
    if (!mounted) return;

    final sub = res['subscription'];
    final pending = res['pending_upgrade'];

    setState(() {
      _isLoading = false;
      _isSubscribed = res['is_premium'] ?? false;
      if (sub != null) {
        _planName = sub['plan_name'];
        _billingCycle = sub['billing_cycle'];
        _endDate = sub['end_date'];
        _autoRenew = sub['auto_renew'] ?? false;
        _status = sub['status'];
      }
      _pendingUpgradeStart = pending?['scheduled_start'];
      _pendingPaymentStatus = pending?['payment_status'];
    });

    // 同步 Provider
    final provider = context.read<UserProvider>();
    provider.setIsPremium(res['is_premium'] ?? false);
    if (res.containsKey('j_pts')) {
      provider.setJPts((res['j_pts'] as num).toInt());
    }
    if (res.containsKey('trial_used')) {
      provider.setTrialUsed(res['trial_used'] == true);
    }
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

  Future<void> _cancelSubscription() async {
    // 🌟 升級版：取消時提供挽留選項
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確定要取消嗎？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('取消後將停止自動續訂，您的 Premium 權益將於到期日後終止。'),
            const SizedBox(height: 15),
            // 挽留選項：年繳更便宜！
            if (_billingCycle == 'monthly')
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: _gold),
                title: const Text('升級為年繳方案 (更划算)'),
                subtitle: const Text('年繳 NT\$1290，現省 NT\$498 並贈送 300 點'),
                onTap: () => Navigator.pop(ctx, 'upgrade'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'back'), child: const Text('我再想想')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('確認取消', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'upgrade') {
      // 導回商城頁面或直接打開 checkout
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreDashboardScreen(initialIndex: 0)));
    } else if (choice == 'cancel') {
      _executeCancellation(); // 執行原本的取消 API
    }
  }

  Future<void> _executeCancellation() async {
    setState(() => _isCancelling = true);
    final userId = context.read<UserProvider>().userId!;
    final res = await ApiClient.cancelSubscription(userId);
    if (!mounted) return;
    setState(() => _isCancelling = false);

    if (!res.containsKey('error')) {
      setState(() { 
        _autoRenew = false; 
        _status = 'cancelled'; 
        // cancelled 的訂閱在邏輯上依然屬於 "已訂閱 (Premium)" 狀態 (直到到期)
        _isSubscribed = true; 
      });
      
      // 更新 Provider
      context.read<UserProvider>().setSubscriptionInfo(
        endDate: _endDate, 
        autoRenew: false, 
        status: 'cancelled', 
        planName: _planName, 
        billingCycle: _billingCycle
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消自動續訂')));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _cycleLabel(String? cycle) {
    if (cycle == 'yearly') return '年繳';
    if (cycle == 'monthly') return '月繳';
    return cycle ?? '—';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return '生效中';
      case 'cancelled':
        return '已取消自動續訂';
      case 'expired':
        return '已到期';
      case 'trial':
        return '試用中';
      default:
        return status ?? '未知';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return _green;
      case 'trial':
        return _gold;
      case 'cancelled':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('訂閱管理'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSubscribed
              ? _buildSubscribedView()
              : _buildNoSubscriptionView(),
    );
  }

  Widget _buildSubscribedView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 方案卡容器
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.verified, color: _green, size: 28),
                const SizedBox(width: 10),
                Text(
                  _billingCycle == 'yearly'
                      ? 'Premium Pro 年訂閱'
                      : _billingCycle == 'monthly'
                          ? 'Premium Pro 月訂閱'
                          : (_planName ?? 'Premium Pro'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textDark),
                ),
              ]),
              const SizedBox(height: 16),
              _infoRow('計費週期', _cycleLabel(_billingCycle)),
              _infoRow('到期日', _formatDate(_endDate)),
                            
              if (_status == 'trial')
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '試用期間：自動續訂將於 ${_formatDate(_endDate)} 開啟',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 12),
              // 狀態 chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(_status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(_status)),
                ),
                child: Text(_statusLabel(_status), style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 自動續訂區塊
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                _autoRenew ? Icons.autorenew : Icons.cancel_outlined,
                color: _autoRenew ? _green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _autoRenew ? '自動續訂已開啟' : '自動續訂已關閉',
                  style: TextStyle(
                    color: _autoRenew ? _green : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 升級至年繳按鈕（月繳 active/trial 且無排程時顯示）
        if ((_status == 'active' || _status == 'trial') &&
            _billingCycle != 'yearly') ...[
          if (_pendingUpgradeStart != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.schedule, color: _gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已排程升級至年繳，將於 ${_formatDate(_pendingUpgradeStart)} 生效',
                        style: const TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    _pendingPaymentStatus == 'pending'
                        ? '尚未付款，屆時完成付款後才會啟動年繳方案。'
                        : '已完成付款，屆時將自動啟動年繳方案。',
                    style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isScheduling ? null : _openPendingUpgradePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isScheduling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('前往付款', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isScheduling ? null : _cancelScheduleUpgrade,
                    child: const Text('取消排程', style: TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.workspace_premium, size: 18),
                label: const Text('升級至年繳方案（省更多）'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isScheduling ? null : _scheduleYearlyUpgrade,
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('NT\$1290/年，平均每月只要 NT\$107，贈 300 點', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 12),
          ],
        ],

        // 取消按鈕（只在 active/trial 時顯示）
        if (_status == 'active' || _status == 'trial')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isCancelling ? null : _cancelSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.red, strokeWidth: 2))
                  : const Text('取消自動續訂', style: TextStyle(fontSize: 16)),
            ),
          ),

        if (_status == 'cancelled') ...[
          const SizedBox(height: 8),
          Text(
            '訂閱已取消自動續訂。效期至 ${_formatDate(_endDate)}，到期後將回復免費方案。',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _scheduleYearlyUpgrade() async {
    setState(() => _isScheduling = true);
    final userId = context.read<UserProvider>().userId!;
    final res = await ApiClient.scheduleYearlyUpgrade(userId);
    if (!mounted) return;
    setState(() => _isScheduling = false);
    if (res.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'].toString())));
    } else {
      setState(() {
        _pendingUpgradeStart = res['scheduled_start'];
        _pendingPaymentStatus = res['payment_status'];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已排程升級至年繳！')));
    }
  }

  Future<void> _openPendingUpgradePayment() async {
    setState(() => _isScheduling = true);
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionCheckoutScreen(
          planId: 0,
          planName: 'Premium Pro (年繳)',
          priceMonthly: 0,
          priceYearly: 1290,
          features: const [
            '包含月繳所有特權',
            '一次性獲得 300 J-Pts',
            '最划算的長期學習投資',
          ],
          pointsGrantMonthly: 0,
          pointsGrantYearly: 300,
          initialBillingCycle: 'yearly',
          isPendingUpgrade: true,
          pendingUpgradeStart: _pendingUpgradeStart,
          currentSubscriptionEndDate: _endDate,
        ),
      ),
    ) ?? false;
    if (!mounted) return;
    setState(() => _isScheduling = false);
    if (success) {
      await _loadStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已完成付款，屆時將自動啟動年繳方案')));
    }
  }

  Future<void> _cancelScheduleUpgrade() async {
    setState(() => _isScheduling = true);
    final userId = context.read<UserProvider>().userId!;
    final res = await ApiClient.cancelScheduleUpgrade(userId);
    if (!mounted) return;
    setState(() => _isScheduling = false);
    if (res.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'].toString())));
    } else {
      setState(() => _pendingUpgradeStart = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消排程升級')));
    }
  }

  Widget _buildNoSubscriptionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_outlined, size: 80, color: _gold),
            const SizedBox(height: 16),
            const Text('目前沒有有效訂閱',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            const SizedBox(height: 8),
            const Text('升級 Premium 解鎖所有功能',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const StoreDashboardScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('查看訂閱方案', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _textDark)),
        ],
      ),
    );
  }
}

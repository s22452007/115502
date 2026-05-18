import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

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

  String? _planName;
  String? _billingCycle;
  String? _endDate;
  bool _autoRenew = false;
  String? _status;

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
    setState(() {
      _isLoading = false;
      _isSubscribed = res['is_premium'] ?? false;
      final sub = res['subscription'];
      if (sub != null) {
        _planName = sub['plan_name'];
        _billingCycle = sub['billing_cycle'];
        _endDate = sub['end_date'];
        _autoRenew = sub['auto_renew'] ?? false;
        _status = sub['status'];
      }
    });

    // 同步 Provider
    final provider = context.read<UserProvider>();
    provider.setIsPremium(res['is_premium'] ?? false);
    if (res['subscription'] != null) {
      final sub = res['subscription'];
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認取消'),
        content: const Text('取消後將停止自動續訂，但可繼續使用至到期日。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認取消', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);
    final userId = context.read<UserProvider>().userId!;
    final res = await ApiClient.cancelSubscription(userId);
    if (!mounted) return;

    setState(() => _isCancelling = false);

    if (!res.containsKey('error')) {
      setState(() {
        _autoRenew = false;
        _status = 'cancelled';
      });
      context.read<UserProvider>().setSubscriptionInfo(
        endDate: _endDate,
        autoRenew: false,
        status: 'cancelled',
        planName: _planName,
        billingCycle: _billingCycle,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? '已取消自動續訂')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? '操作失敗，請稍後再試')),
      );
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
        // 方案卡
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
                Text(_planName ?? 'Premium Pro',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textDark)),
              ]),
              const SizedBox(height: 16),
              _infoRow('計費週期', _cycleLabel(_billingCycle)),
              _infoRow('到期日', _formatDate(_endDate)),
              const SizedBox(height: 12),
              // 狀態 chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(_status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(_status)),
                ),
                child: Text(
                  _statusLabel(_status),
                  style: TextStyle(
                      color: _statusColor(_status),
                      fontWeight: FontWeight.w600),
                ),
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

        // 取消按鈕（只在 active 時顯示）
        if (_status == 'active')
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

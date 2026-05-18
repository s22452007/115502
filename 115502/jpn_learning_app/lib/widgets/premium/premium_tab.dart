import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/premium/subscription_management_screen.dart';
import 'package:jpn_learning_app/screens/premium/subscription_checkout_screen.dart';
import 'package:jpn_learning_app/screens/premium/premium_trial_screen.dart';

class PremiumTab extends StatefulWidget { 
  const PremiumTab({Key? key}) : super(key: key); 
  @override 
  State<PremiumTab> createState() => _PremiumTabState(); 
}

class _PremiumTabState extends State<PremiumTab> {
  Map<String, dynamic>? _plan;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadPlans(); }

  Future<void> _loadPlans() async {
    try {
      final res = await ApiClient.getSubscriptionPlans();
      if (!mounted) return;
      final plans = res['plans'] as List?;
      if (plans != null && plans.isNotEmpty) {
        setState(() { _plan = plans.first as Map<String, dynamic>; _isLoading = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<UserProvider>().isPremium;
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isPremium) ...[
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen())),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFEAF4EA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF4E8B4C), width: 1.5)),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF4E8B4C), size: 24), SizedBox(width: 10),
                  Expanded(child: Text('Premium 已啟用 — 點此管理訂閱', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E8B4C)))),
                  Icon(Icons.chevron_right, color: Color(0xFF4E8B4C)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        _buildPlanCard(
          title: 'Free (免費版)',
          isPro: false,
          priceText: '\$ 0/月',
          features: ['每日最多 3 次 AI 對話', '每日最多 3 次場景照片上傳', '基本學習結果'],
          btnText: '目前方案',
          onTap: null,
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          title: 'Premium Pro',
          isPro: true,
          priceText: _plan != null ? '\$ ${_plan!['price_monthly']}/月  \$ ${_plan!['price_yearly']}/年' : '\$ 490/月  \$ 1280/年',
          features: _plan != null ? List<String>.from(_plan!['features'] ?? []) : ['無限使用，免廣告', '無限次 AI 對話與照片上傳', '詳細學習分析報告', '每月贈送 1000 Points'],
          btnText: isPremium ? '管理訂閱' : '免費試用',
          onTap: () {
            if (isPremium) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()));
            } else if (_plan == null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumTrialScreen()));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionCheckoutScreen(
                planId: _plan!['id'], planName: _plan!['name'], priceMonthly: _plan!['price_monthly'], priceYearly: _plan!['price_yearly'], features: List<String>.from(_plan!['features']), pointsGrant: _plan!['points_grant'],
              )));
            }
          },
        ),
      ],
    );
  }

  Widget _buildPlanCard({required String title, required bool isPro, required String priceText, required List<String> features, required String btnText, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: isPro ? const Color(0xFFC6B13B) : const Color(0xFF4E8B4C), width: isPro ? 2 : 1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPro) const Icon(Icons.workspace_premium, color: Color(0xFFC6B13B), size: 24),
              if (isPro) const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPro ? const Color(0xFFC6B13B) : const Color(0xFF4E8B4C))),
              const Spacer(),
              if (onTap != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isPro ? const Color(0xFFC6B13B) : Colors.grey.shade300, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: onTap,
                  child: Text(btnText, style: TextStyle(color: isPro ? Colors.white : Colors.black54, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(priceText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check, color: Color(0xFF4E8B4C), size: 18), const SizedBox(width: 8), Expanded(child: Text(f, style: const TextStyle(color: Color(0xFF555555), height: 1.4)))]))),
        ],
      ),
    );
  }
}
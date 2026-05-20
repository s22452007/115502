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
  Map<String, dynamic>? _monthlyPlan;
  Map<String, dynamic>? _yearlyPlan;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadPlans(); }

  Future<void> _loadPlans() async {
    try {
      final res = await ApiClient.getSubscriptionPlans();
      if (!mounted) return;
      final plans = (res['plans'] as List? ?? []).cast<Map<String, dynamic>>();
      // 找月/年方案；若無 billing_cycle 欄位則以 price 有值判斷
      Map<String, dynamic>? monthly;
      Map<String, dynamic>? yearly;
      for (final p in plans) {
        final cycle = p['billing_cycle'] as String?;
        if (cycle == 'monthly') { monthly = p; }
        else if (cycle == 'yearly') { yearly = p; }
        else if (monthly == null && (p['price_monthly'] != null && p['price_monthly'] != 0)) { monthly = p; }
        else if (yearly == null && (p['price_yearly'] != null && p['price_yearly'] != 0)) { yearly = p; }
      }
      setState(() {
        _monthlyPlan = monthly ?? (plans.isNotEmpty ? plans.first : null);
        _yearlyPlan  = yearly  ?? (plans.isNotEmpty ? plans.first : null);
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _goToCheckout(String cycle) {
    final plan = cycle == 'monthly' ? _monthlyPlan : _yearlyPlan;
    if (plan == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionCheckoutScreen(
      planId: plan['id'],
      planName: cycle == 'monthly' ? 'Premium (月繳)' : 'Premium Pro (年繳)',
      priceMonthly: (plan['price_monthly'] as num?)?.toInt() ?? 149,
      priceYearly: (plan['price_yearly'] as num?)?.toInt() ?? 1290,
      features: List<String>.from(plan['features_json'] ?? [
        '每日 10 次拍照辨識', '每日 10 次 AI 對話', '單字收藏擴充 6 折', '小組押金 5 折'
      ]),
      pointsGrantMonthly: (plan['points_grant_monthly'] as num?)?.toInt() ?? 20,
      pointsGrantYearly: (plan['points_grant_yearly'] as num?)?.toInt() ?? 300,
      initialBillingCycle: cycle,
    )));
  }

  void _goToTrialScreen() {
    final price = (_monthlyPlan?['price_monthly'] as num?)?.toInt() ?? 99;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumTrialScreen(priceMonthly: price)));
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isPremium = userProvider.isPremium;
    final trialUsed = userProvider.trialUsed;
    final String currentCycle = userProvider.billingCycle ?? '';

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF4E8B4C)));

    // 月繳按鈕邏輯
    // 情況A: 已訂閱月繳 → 目前方案
    // 情況A2: 已訂閱（其他週期）→ 切換為月繳
    // 情況B: 未訂閱 + 未試用 → 開始 7 天免費試用
    // 情況C: 未訂閱 + 已試用 → 立即訂閱
    final String monthlyBtnText;
    final VoidCallback? monthlyOnTap;
    final String? monthlyBtnSubText;

    if (isPremium && currentCycle == 'monthly') {
      monthlyBtnText = '目前方案';
      monthlyOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()));
      monthlyBtnSubText = null;
    } else if (isPremium) {
      monthlyBtnText = '切換為月繳';
      monthlyOnTap = () => _goToCheckout('monthly');
      monthlyBtnSubText = null;
    } else if (!trialUsed) {
      monthlyBtnText = '開始 7 天免費試用';
      monthlyOnTap = _goToTrialScreen;
      monthlyBtnSubText = null;
    } else {
      monthlyBtnText = '立即訂閱';
      monthlyOnTap = () => _goToCheckout('monthly');
      monthlyBtnSubText = '免費試用資格已使用';
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isPremium) ...[
          _buildManagementBanner(),
          const SizedBox(height: 20),
        ],

        // Free 方案
        _buildPlanCard(
          title: 'Free (免費版)',
          isPro: false,
          isCurrent: !isPremium,
          priceText: 'NT\$ 0 / 月',
          features: ['每日最多 3 次 AI 對話', '每日最多 2 次場景照片上傳', '單字收藏上限 100 個', '基本學習結果'],
          btnText: !isPremium ? '目前方案' : null,
          onTap: null,
        ),
        const SizedBox(height: 16),

        // 月繳方案
        _buildPlanCard(
          title: 'Premium (月繳)',
          isPro: true,
          isCurrent: isPremium && currentCycle == 'monthly',
          badgeText: '每月送 20 點',
          priceText: 'NT\$ 149 / 月',
          features: ['享 7 天免費試用，隨時可取消', '每日 10 次拍照辨識', '每日 10 次 AI 對話', '單字擴充 6 折、小組押金 5 折'],
          btnText: monthlyBtnText,
          btnSubText: monthlyBtnSubText,
          btnColor: const Color(0xFF4E8B4C),
          onTap: monthlyOnTap,
        ),
        const SizedBox(height: 16),

        // 年繳方案
        _buildPlanCard(
          title: 'Premium Pro (年繳)',
          isPro: true,
          isCurrent: isPremium && currentCycle == 'yearly',
          badgeText: '最划算！狂贈 300 點',
          priceText: 'NT\$ 1290 / 年',
          subtitle: '平均每月只要 NT\$ 107，現省 NT\$ 498！',
          features: ['包含月繳所有特權', '一次性獲得 300 J-Pts', '最划算的長期學習投資'],
          btnText: (isPremium && currentCycle == 'yearly')
              ? '目前方案'
              : (isPremium ? '切換為年繳' : '立即升級年繳'),
          btnColor: const Color(0xFFC6B13B),
          onTap: (isPremium && currentCycle == 'yearly')
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
              : () => _goToCheckout('yearly'),
        ),
      ],
    );
  }

  // 新增：上方管理條，讓頁面乾淨
  Widget _buildManagementBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEAF4EA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF4E8B4C), width: 1.5)),
        child: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF4E8B4C), size: 24), SizedBox(width: 10),
            Expanded(child: Text('您已訂閱 Premium，點此管理訂閱資訊', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E8B4C)))),
            Icon(Icons.chevron_right, color: Color(0xFF4E8B4C)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required bool isPro,
    required bool isCurrent,
    required String priceText,
    String? subtitle,
    String? badgeText,
    required List<String> features,
    String? btnText,
    String? btnSubText,
    Color? btnColor,
    VoidCallback? onTap,
  }) {
    final titleColor = isPro ? const Color(0xFFC6B13B) : const Color(0xFF4E8B4C);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: titleColor, width: isPro ? 2 : 1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPro) const Icon(Icons.workspace_premium, color: Color(0xFFC6B13B), size: 24),
              if (isPro) const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC6B13B))),
                  child: Text(badgeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC6B13B))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(priceText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(isPro ? Icons.check_circle : Icons.check, color: isPro ? const Color(0xFF4E8B4C) : Colors.grey, size: 18), const SizedBox(width: 8), Expanded(child: Text(f, style: const TextStyle(color: Color(0xFF555555), height: 1.4)))]))),
          const SizedBox(height: 10),
          if (btnText != null && btnText.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent ? Colors.grey.shade300 : (btnColor ?? const Color(0xFF4E8B4C)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isCurrent ? null : onTap,
                child: Text(
                  btnText,
                  style: TextStyle(
                    color: isCurrent ? Colors.black54 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (btnSubText != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  btnSubText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/premium/plan_card.dart';
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
  void initState() { super.initState(); _loadPlans(); _loadSubscriptionStatus(); }

  Future<void> _loadSubscriptionStatus() async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null || !provider.isPremium) return;
    final res = await ApiClient.getSubscriptionStatus(userId);
    if (!mounted) return;
    provider.setPendingUpgradeStart(res['pending_upgrade']?['scheduled_start'] as String?);
  }

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
        '每日 10 次拍照辨識', '每日 10 次 AI 對話', '單字收藏擴充 7 折', '小組押金 5 折'
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

  String _formatIsoDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return formatDate(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isPremium = userProvider.isPremium;
    final trialUsed = userProvider.trialUsed;
    final String currentCycle = userProvider.billingCycle ?? '';

    final pendingUpgradeStart = userProvider.pendingUpgradeStart;

    if (_isLoading) return Center(child: const CircularProgressIndicator(color: AppColors.primary));

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
    } else if (isPremium && currentCycle == 'yearly') {
      monthlyBtnText = '前往訂閱管理';
      monthlyOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()));
      monthlyBtnSubText = '目前已是年繳方案';
    } else if (isPremium) {
      monthlyBtnText = '切換為月繳';
      monthlyOnTap = () => _goToCheckout('monthly');
      monthlyBtnSubText = null;
    } else if (!trialUsed) {
      monthlyBtnText = '開始 7 天免費試用';
      monthlyOnTap = _goToTrialScreen;
      monthlyBtnSubText = null;
    } else {
      monthlyBtnText = '立即訂閱月繳';
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
        PlanCard(
          title: 'Free (免費版)',
          isPro: false,
          isCurrent: !isPremium,
          priceText: 'NT\$ 0 / 月',
          features: ['每日最多 3 次 AI 對話', '每日最多 2 次場景照片上傳', '單字收藏上限 50 個', '基本學習結果'],
          btnText: !isPremium ? '目前方案' : null,
          onTap: null,
        ),
        const SizedBox(height: 16),

        // 月繳方案
        PlanCard(
          title: 'Premium (月繳)',
          isPro: true,
          isCurrent: isPremium && currentCycle == 'monthly',
          badgeText: '每月送 20 點',
          priceText: 'NT\$ 149 / 月',
          features: ['享 7 天免費試用，隨時可取消', '每日 10 次拍照辨識', '每日 10 次 AI 對話', '單字擴充 7 折、小組押金 5 折'],
          btnText: monthlyBtnText,
          btnSubText: monthlyBtnSubText,
          btnColor: AppColors.primary,
          onTap: monthlyOnTap,
        ),
        const SizedBox(height: 16),

        // 年繳方案
        PlanCard(
          title: 'Premium Pro (年繳)',
          isPro: true,
          isCurrent: isPremium && currentCycle == 'yearly',
          badgeText: '最划算！狂贈 300 點',
          priceText: 'NT\$ 1290 / 年',
          subtitle: '平均每月只要 NT\$ 107，現省 NT\$ 498！',
          features: ['包含月繳所有特權', '一次性獲得 300 J-Pts', '最划算的長期學習投資'],
          isScheduledUpgrade: isPremium && currentCycle == 'monthly' && pendingUpgradeStart != null,
          scheduledDate: _formatIsoDate(pendingUpgradeStart),
          btnText: (isPremium && currentCycle == 'yearly')
              ? '目前方案'
              : (isPremium && pendingUpgradeStart != null)
                  ? null
                  : (isPremium ? '排程升級為年繳' : '立即升級年繳'),
          btnColor: AppColors.secondary,
          onTap: (isPremium && currentCycle == 'yearly')
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
              : (isPremium && pendingUpgradeStart == null)
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
                  : (!isPremium ? () => _goToCheckout('yearly') : null),
        ),
      ],
    );
  }

  Widget _buildManagementBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary, width: 1.5)),
        child: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.primary, size: 24), SizedBox(width: 10),
            Expanded(child: Text('您已訂閱 Premium，點此管理訂閱資訊', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
            Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
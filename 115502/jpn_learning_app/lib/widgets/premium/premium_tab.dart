import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
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

  // 🌟 與儲值點數分頁完全統一的扁平化配色設定
  static const Color _textDark = Color(0xFF2C3E50);
  static const Color _subText = Color(0xFF8E9AAB);

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
      return "${dt.year}/${dt.month}/${dt.day}";
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

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

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
          const SizedBox(height: 16),
        ],

        // 1. Free 方案卡片
        _buildFlatPlanCard(
          title: 'Free (免費版)',
          isCurrent: !isPremium,
          priceText: 'NT\$ 0 / 月',
          features: ['每日最多 3 次 AI 對話', '每日最多 2 次場景照片上傳', '單字收藏上限 50 個', '基本學習結果'],
          btnText: !isPremium ? '目前方案' : null,
          onTap: null,
        ),
        const SizedBox(height: 14),

        // 2. 月繳方案卡片
        _buildFlatPlanCard(
          title: 'Premium (月繳)',
          isCurrent: isPremium && currentCycle == 'monthly',
          badgeText: '每月贈送 20 點', 
          priceText: 'NT\$ 149 / 月',
          features: ['享 7 天免費試用，隨時可取消', '每日 10 次拍照辨識', '每日 10 次 AI 對話', '單字擴充 7 折、小組押金 5 折'],
          btnText: monthlyBtnText,
          btnSubText: monthlyBtnSubText,
          btnColor: AppColors.primary,
          onTap: monthlyOnTap,
        ),
        const SizedBox(height: 14),

        // 3. 年繳方案卡片
        _buildFlatPlanCard(
          title: 'Premium Pro (年繳)',
          isCurrent: isPremium && currentCycle == 'yearly',
          badgeText: '年度精選 贈送 300 點', 
          priceText: 'NT\$ 1290 / 年',
          subtitle: '平均每月只要 NT\$ 107，現省 NT\$ 498！',
          features: ['包含月繳所有特權', '一次性獲得 300 J-Pts', '最劃算的長期學習投資'],
          isScheduledUpgrade: isPremium && currentCycle == 'monthly' && pendingUpgradeStart != null,
          scheduledDate: _formatIsoDate(pendingUpgradeStart),
          btnText: (isPremium && currentCycle == 'yearly')
              ? '目前方案'
              : (isPremium && pendingUpgradeStart != null)
                  ? null
                  : (isPremium ? '排程升級為年繳' : '立即升級年繳'),
          btnColor: const Color(0xFFFF7043), // 🌟 與儲值點數的「最划算橘色」遙相呼應
          onTap: (isPremium && currentCycle == 'yearly')
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
              : (isPremium && pendingUpgradeStart == null)
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
                  : (!isPremium ? () => _goToCheckout('yearly') : null),
        ),
      ],
    );
  }

  // 🌟 與儲值分頁完全同款的「扁平化精緻方案組件」
  Widget _buildFlatPlanCard({
    required String title,
    required String priceText,
    required List<String> features,
    required bool isCurrent,
    String? badgeText,
    String? subtitle,
    String? btnText,
    String? btnSubText,
    Color? btnColor,
    VoidCallback? onTap,
    bool isScheduledUpgrade = false,
    String? scheduledDate,
  }) {
    final Color mainColor = btnColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // 24級高雅圓角
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isCurrent ? AppColors.primary : _textDark)),
              if (badgeText != null && badgeText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: title.contains('Pro') ? const Color(0xFFFF7043) : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badgeText, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(priceText, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _textDark)),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFEDF3EF), height: 1, thickness: 1), // 極輕極淡分隔線
          ),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: isCurrent ? AppColors.primary : AppColors.primary.withOpacity(0.3), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w600))),
              ],
            ),
          )),
          if (isScheduledUpgrade && scheduledDate != null && scheduledDate.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12)),
              child: Text('將於 $scheduledDate 自動切換為此方案', style: const TextStyle(fontSize: 13, color: Color(0xFFF57F17), fontWeight: FontWeight.w700)),
            ),
          ],
          if (btnText != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent ? const Color(0xFFEDF3EF) : mainColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onTap,
                child: Text(
                  btnText, 
                  style: TextStyle(
                    color: isCurrent ? AppColors.primary : Colors.white, 
                    fontWeight: FontWeight.w900, 
                    fontSize: 15
                  )
                ),
              ),
            ),
          ],
          if (btnSubText != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(btnSubText, style: const TextStyle(fontSize: 12, color: _subText, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22), 
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '您已訂閱 Premium，點此管理訂閱資訊', 
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14)
              )
            ),
            // 🌟 修正點：已換成系統確切支援的標準 arrow_forward_ios，紅線完全清除
            Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
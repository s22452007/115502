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
  // 後台上架中的訂閱方案（月繳在前、年繳在後），卡片依此畫出，後台改價、停用、新增方案都會反映
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _monthlyPlan;
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
      final monthly = plans.where((p) => _cycleOf(p) == 'monthly').toList();
      final yearly = plans.where((p) => _cycleOf(p) == 'yearly').toList();
      setState(() {
        _plans = [...monthly, ...yearly];
        _monthlyPlan = monthly.isNotEmpty ? monthly.first : null;
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  // 舊資料可能沒有 billing_cycle，依有填的價格判斷
  static String _cycleOf(Map<String, dynamic> p) {
    final cycle = p['billing_cycle'] as String?;
    if (cycle == 'monthly' || cycle == 'yearly') return cycle!;
    final monthly = (p['price_monthly'] as num?) ?? 0;
    return monthly > 0 ? 'monthly' : 'yearly';
  }

  // 同一種週期只有一個方案時沿用原本的標題，有多個時用後台設定的方案名稱區分
  String _cardTitle(Map<String, dynamic> plan) {
    final cycle = _cycleOf(plan);
    final sameCycle = _plans.where((p) => _cycleOf(p) == cycle).length;
    if (sameCycle > 1) return plan['name']?.toString() ?? '';
    return cycle == 'monthly' ? 'Premium (月繳)' : 'Premium (年繳)';
  }

  void _goToCheckout(Map<String, dynamic>? plan) {
    if (plan == null) return;
    final cycle = _cycleOf(plan);
    Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionCheckoutScreen(
      planId: plan['id'],
      planName: _cardTitle(plan),
      priceMonthly: (plan['price_monthly'] as num?)?.toInt() ?? 149,
      priceYearly: (plan['price_yearly'] as num?)?.toInt() ?? 1290,
      features: List<String>.from(plan['features_json'] ?? [
        '每日 10 次拍照辨識', '每日 10 次 AI 對話', '每日 5 次造句 AI 批改', '每日 5 次文章朗讀評分',
        '單字收藏擴充半價', '小組押金 5 折'
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

    final currentPlanName = userProvider.subscriptionPlanName;

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
          features: ['每日最多 2 次拍照辨識', '每日最多 3 次 AI 對話', '每日 3 次造句 AI 批改', '每日 1 次文章朗讀評分', '單字收藏上限 50 個'],
          btnText: !isPremium ? '目前方案' : null,
          onTap: null,
        ),

        // 2. 後台上架中的訂閱方案（月繳在前、年繳在後）
        for (final plan in _plans) ...[
          const SizedBox(height: 14),
          _cycleOf(plan) == 'monthly'
              ? _buildMonthlyCard(plan, isPremium: isPremium, trialUsed: trialUsed, currentCycle: currentCycle, currentPlanName: currentPlanName)
              : _buildYearlyCard(plan, isPremium: isPremium, currentCycle: currentCycle, currentPlanName: currentPlanName, pendingUpgradeStart: pendingUpgradeStart),
        ],
      ],
    );
  }

  // 同週期有多個方案時，用目前訂閱的方案名稱判斷是哪一張
  bool _isCurrentPlan(Map<String, dynamic> plan, {required bool isPremium, required String currentCycle, required String? currentPlanName}) {
    final cycle = _cycleOf(plan);
    if (!isPremium || currentCycle != cycle) return false;
    final sameCycle = _plans.where((p) => _cycleOf(p) == cycle).length;
    if (sameCycle == 1) return true;
    return currentPlanName == plan['name'] || currentPlanName == _cardTitle(plan);
  }

  Widget _buildMonthlyCard(Map<String, dynamic> plan, {required bool isPremium, required bool trialUsed, required String currentCycle, required String? currentPlanName}) {
    final isCurrent = _isCurrentPlan(plan, isPremium: isPremium, currentCycle: currentCycle, currentPlanName: currentPlanName);
    final isTrialPlan = identical(plan, _monthlyPlan);
    final price = (plan['price_monthly'] as num?)?.toInt() ?? 0;
    final points = (plan['points_grant_monthly'] as num?)?.toInt() ?? 0;

    final String btnText;
    final VoidCallback? onTap;
    String? btnSubText;
    if (isCurrent) {
      btnText = '目前方案';
      onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()));
    } else if (isPremium && currentCycle == 'yearly') {
      btnText = '前往訂閱管理';
      onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()));
      btnSubText = '目前已是年繳方案';
    } else if (isPremium) {
      btnText = '切換為月繳';
      onTap = () => _goToCheckout(plan);
    } else if (!trialUsed && isTrialPlan) {
      btnText = '開始 7 天免費試用';
      onTap = _goToTrialScreen;
    } else {
      btnText = '立即訂閱月繳';
      onTap = () => _goToCheckout(plan);
      if (trialUsed) btnSubText = '免費試用資格已使用';
    }

    return _buildFlatPlanCard(
      title: _cardTitle(plan),
      isCurrent: isCurrent,
      badgeText: points > 0 ? '每月贈送 $points 點' : null,
      priceText: 'NT\$ $price / 月',
      features: [
        if (isTrialPlan) '享 7 天免費試用，隨時可取消',
        '每日 10 次拍照辨識', '每日 10 次 AI 對話', '每日 5 次造句 AI 批改', '每日 5 次文章朗讀評分', '單字擴充半價、小組押金 5 折',
      ],
      btnText: btnText,
      btnSubText: btnSubText,
      btnColor: AppColors.primary,
      onTap: onTap,
    );
  }

  Widget _buildYearlyCard(Map<String, dynamic> plan, {required bool isPremium, required String currentCycle, required String? currentPlanName, required String? pendingUpgradeStart}) {
    final isCurrent = _isCurrentPlan(plan, isPremium: isPremium, currentCycle: currentCycle, currentPlanName: currentPlanName);
    final price = (plan['price_yearly'] as num?)?.toInt() ?? 0;
    final points = (plan['points_grant_yearly'] as num?)?.toInt() ?? 0;

    // 和第一個月繳方案比較，算出平均月費與一年省下的金額
    String? subtitle;
    final monthlyPrice = (_monthlyPlan?['price_monthly'] as num?)?.toInt();
    if (price > 0) {
      final avg = (price / 12).round();
      final saved = monthlyPrice == null ? 0 : monthlyPrice * 12 - price;
      subtitle = saved > 0 ? '平均每月只要 NT\$ $avg，現省 NT\$ $saved！' : '平均每月只要 NT\$ $avg';
    }

    return _buildFlatPlanCard(
      title: _cardTitle(plan),
      isCurrent: isCurrent,
      badgeText: points > 0 ? '年度精選 贈送 $points 點' : null,
      priceText: 'NT\$ $price / 年',
      subtitle: subtitle,
      features: ['包含月繳所有特權', if (points > 0) '一次性獲得 $points J-Pts', '最劃算的長期學習投資'],
      isScheduledUpgrade: isPremium && currentCycle == 'monthly' && pendingUpgradeStart != null,
      scheduledDate: _formatIsoDate(pendingUpgradeStart),
      btnText: (isPremium && currentCycle == 'yearly')
          ? (isCurrent ? '目前方案' : '前往訂閱管理')
          : (isPremium && pendingUpgradeStart != null)
              ? null
              : (isPremium ? '排程升級為年繳' : '立即升級年繳'),
      btnColor: const Color(0xFFFF7043), // 🌟 與儲值點數的「最划算橘色」遙相呼應
      onTap: isPremium
          ? ((currentCycle == 'yearly' || pendingUpgradeStart == null)
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
              : null)
          : () => _goToCheckout(plan),
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
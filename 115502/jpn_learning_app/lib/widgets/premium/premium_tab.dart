import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/premium/subscription_management_screen.dart';
import 'package:jpn_learning_app/screens/premium/subscription_checkout_screen.dart';

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
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _goToCheckout(String cycle) {
    if (_plan == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionCheckoutScreen(
      planId: _plan!['id'],
      planName: cycle == 'monthly' ? 'Premium (月繳)' : 'Premium Pro (年繳)',
      priceMonthly: (_plan!['price_monthly'] as num?)?.toInt() ?? 99,
      priceYearly: (_plan!['price_yearly'] as num?)?.toInt() ?? 899,
      features: List<String>.from(_plan!['features_json'] ?? [
        '每日 20 次拍照辨識', '每日 30 次 AI 對話', '單字收藏擴充 6 折', '小組押金 5 折'
      ]),
      pointsGrantMonthly: (_plan!['points_grant_monthly'] as num?)?.toInt() ?? 50,
      pointsGrantYearly: (_plan!['points_grant_yearly'] as num?)?.toInt() ?? 600,
      initialBillingCycle: cycle, // 帶入預設選擇的週期
    )));
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isPremium = userProvider.isPremium;
    // 假設你後端有回傳 billing_cycle，這裡從 provider 讀取
    final String currentCycle = userProvider.billingCycle ?? ''; 
    
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF4E8B4C)));

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
          isCurrent: !isPremium, // 如果沒訂閱，這就是目前方案
          priceText: 'NT\$ 0 / 月',
          features: ['每日最多 3 次 AI 對話', '每日最多 3 次場景照片上傳', '單字收藏上限 50 個', '基本學習結果'],
          btnText: !isPremium ? '目前方案' : null,
          onTap: null,
        ),
        const SizedBox(height: 16),

        // 月繳方案
        _buildPlanCard(
          title: 'Premium (月繳)',
          isPro: true,
          isCurrent: isPremium && currentCycle == 'monthly',
          badgeText: '每月送 50 點',
          priceText: 'NT\$ 99 / 月',
          features: ['享 7 天免費試用，隨時可取消', '每日 20 次拍照辨識', '每日 30 次 AI 對話', '單字擴充 6 折、小組押金 5 折'],
          btnText: (isPremium && currentCycle == 'monthly') 
              ? '目前方案' 
              : (isPremium ? '切換為月繳' : '開始 7 天免費試用'),
          btnColor: const Color(0xFF4E8B4C),
          onTap: (isPremium && currentCycle == 'monthly') 
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()))
              : () => _goToCheckout('monthly'),
        ),
        const SizedBox(height: 16),

        // 年繳方案
        _buildPlanCard(
          title: 'Premium Pro (年繳)',
          isPro: true,
          isCurrent: isPremium && currentCycle == 'yearly',
          badgeText: '最划算！狂贈 600 點',
          priceText: 'NT\$ 899 / 年',
          subtitle: '平均每月只要 NT\$ 74，現省 NT\$ 289！',
          features: ['包含月繳所有特權', '一次性獲得 600 J-Pts', '最划算的長期學習投資'],
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
    required bool isCurrent, // 如果你有加這個參數
    required String priceText,
    String? subtitle,
    String? badgeText,
    required List<String> features,
    String? btnText, // <--- 加上問號，表示可以傳 null
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
          // 🌟 這裡判斷：如果 btnText 有內容才顯示按鈕
          if (btnText != null && btnText.isNotEmpty)
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
        ],
      ),
    );
  }
}
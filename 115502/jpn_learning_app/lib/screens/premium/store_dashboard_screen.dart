import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

// 匯入會用到的次級跳轉畫面
import 'subscription_management_screen.dart';
import 'subscription_checkout_screen.dart';
import 'premium_trial_screen.dart';
import 'point_checkout_screen.dart';

class StoreDashboardScreen extends StatefulWidget {
  // 🌟 透過這個參數，我們可以決定玩家一進來要在哪一頁 (0: 訂閱, 1: 儲值, 2: 兌換)
  final int initialIndex;
  
  const StoreDashboardScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _darkGreen = Color(0xFF5F8F5B);
  static const Color _bg = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    // 建立 3 個分頁的控制器
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '商城與會員中心',
          style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _darkGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _darkGreen,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: '👑 Premium'),
            Tab(text: '💰 儲值點數'),
            Tab(text: '🛍️ 點數兌換'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PremiumTab(),
          _BuyPointsTab(),
          _StoreTab(),
        ],
      ),
    );
  }
}

// ==========================================
// 👑 分頁一：Premium 訂閱管理
// ==========================================
class _PremiumTab extends StatefulWidget { const _PremiumTab(); @override State<_PremiumTab> createState() => _PremiumTabState(); }
class _PremiumTabState extends State<_PremiumTab> {
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
          features: ['每 10 分鐘觀看一次廣告', '每日最多 3 次 AI 對話', '每日最多 3 次場景照片上傳', '基本學習結果'],
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

// ==========================================
// 💰 分頁二：儲值點數 (法幣購買)
// ==========================================
class _BuyPointsTab extends StatefulWidget { const _BuyPointsTab(); @override State<_BuyPointsTab> createState() => _BuyPointsTabState(); }
class _BuyPointsTabState extends State<_BuyPointsTab> {
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadPackages(); }

  Future<void> _loadPackages() async {
    final res = await ApiClient.getPointPackages();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.containsKey('packages')) _packages = List<Map<String, dynamic>>.from(res['packages']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final jPts = context.watch<UserProvider>().jPts;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildWalletCard(jPts),
        const SizedBox(height: 24),
        const Text('選擇儲值方案', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        const SizedBox(height: 12),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else ..._packages.map((pkg) => _buildPackageCard(context, pkg)),
      ],
    );
  }

  Widget _buildWalletCard(int pts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF7FAF2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD4E1C8))),
      child: Row(
        children: [
          Container(width: 50, height: 50, decoration: const BoxDecoration(color: Color(0xFFE8F0DD), shape: BoxShape.circle), child: const Icon(Icons.monetization_on_outlined, color: Color(0xFF5F8F5B), size: 30)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('目前點數', style: TextStyle(fontSize: 14, color: Color(0xFF7A7A7A))),
              Text('$pts J-Pts', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> pkg) {
    final pts = (pkg['points'] as num).toInt();
    final price = (pkg['price'] as num).toInt();
    final tag = pkg['tag'] as String? ?? '';
    final name = pkg['name'] as String? ?? '$pts Points';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          const Icon(Icons.generating_tokens, color: Color(0xFFF0B84B), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$pts J-Pts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (tag.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF0B84B), borderRadius: BorderRadius.circular(8)), child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                    ]
                  ],
                ),
                Text(name, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5F8F5B), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PointCheckoutScreen(title: name, points: pts, price: price, badge: tag, subtitle: pkg['description']))),
            child: Text('NT\$$price', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 🛍️ 分頁三：點數兌換 (虛擬幣消費)
// ==========================================
class _StoreTab extends StatefulWidget { const _StoreTab(); @override State<_StoreTab> createState() => _StoreTabState(); }
class _StoreTabState extends State<_StoreTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadItems(); }

  Future<void> _loadItems() async {
    final res = await ApiClient.getStoreItems();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.containsKey('items')) _items = List<Map<String, dynamic>>.from(res['items']);
    });
  }

  // 🌟 加入「防呆確認視窗」
  void _showConfirmPurchaseDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('確認兌換', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('確定要花費 ${item['cost']} J-Pts\n兌換「${item['name']}」嗎？', style: const TextStyle(fontSize: 16, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5F8F5B)),
            onPressed: () {
              Navigator.pop(ctx);
              _executePurchase(item);
            },
            child: const Text('確定兌換', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executePurchase(Map<String, dynamic> item) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final cost = (item['cost'] as num).toInt();
    final userPts = context.read<UserProvider>().jPts;

    if (userPts < cost) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('點數不足喔！請先儲值'), backgroundColor: Colors.redAccent));
      return;
    }

    final res = await ApiClient.spendPoints(userId: userId, points: cost, feature: item['id']);
    if (!mounted) return;

    if (res.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']), backgroundColor: Colors.redAccent));
    } else {
      final newPts = (res['total_points'] as num?)?.toInt() ?? userPts - cost;
      context.read<UserProvider>().setJPts(newPts);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 兌換成功！${item['description']}'), backgroundColor: const Color(0xFF5F8F5B)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final jPts = context.watch<UserProvider>().jPts;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildWalletBanner(jPts),
        const SizedBox(height: 24),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else ..._items.map((item) => _buildStoreItemCard(item)),
      ],
    );
  }

  Widget _buildWalletBanner(int pts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB8C8F0))),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: Color(0xFF3B69CC), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('點數餘額', style: TextStyle(fontSize: 12, color: Color(0xFF3B69CC))),
                Text('$pts J-Pts', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3B69CC))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItemCard(Map<String, dynamic> item) {
    final cost = item['cost'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: Color(0xFF8FB98B), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item['description'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0F4FF), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _showConfirmPurchaseDialog(item),
            child: Text('$cost 點', style: const TextStyle(color: Color(0xFF3B69CC), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
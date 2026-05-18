import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/premium/point_checkout_screen.dart';

class BuyPointsTab extends StatefulWidget { 
  const BuyPointsTab({Key? key}) : super(key: key); 
  @override 
  State<BuyPointsTab> createState() => _BuyPointsTabState(); 
}

class _BuyPointsTabState extends State<BuyPointsTab> {
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
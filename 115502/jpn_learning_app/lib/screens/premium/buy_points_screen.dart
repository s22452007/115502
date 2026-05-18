import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';
import 'package:jpn_learning_app/screens/premium/points_store_screen.dart';
import 'point_checkout_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class BuyPointsScreen extends StatefulWidget {
  const BuyPointsScreen({Key? key}) : super(key: key);

  @override
  State<BuyPointsScreen> createState() => _BuyPointsScreenState();
}

class _BuyPointsScreenState extends State<BuyPointsScreen> {
  static const Color primaryGreen = Color(0xFF8FB98B);
  static const Color darkGreen = Color(0xFF5F8F5B);
  static const Color lightGreen = Color(0xFFE8F0DD);
  static const Color borderGreen = Color(0xFFD4E1C8);
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF7A7A7A);
  static const Color gold = Color(0xFFF0B84B);

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTxn = true;
  List<Map<String, dynamic>> _packages = [];
  bool _isLoadingPkgs = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final res = await ApiClient.getPointPackages();
    if (!mounted) return;
    setState(() {
      _isLoadingPkgs = false;
      if (res.containsKey('packages')) {
        _packages = List<Map<String, dynamic>>.from(res['packages']);
      }
    });
  }

  Future<void> _loadTransactions() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoadingTxn = false);
      return;
    }
    final res = await ApiClient.getTransactions(userId);
    if (!mounted) return;
    setState(() {
      _isLoadingTxn = false;
      if (res.containsKey('transactions')) {
        _transactions = List<Map<String, dynamic>>.from(res['transactions']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 上方關閉
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Buy Points',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 4),
              const Text(
                '用 J-Pts 解鎖更多學習互動與分析功能',
                style: TextStyle(
                  fontSize: 14,
                  color: subText,
                ),
              ),

              const SizedBox(height: 18),

              /// 目前點數
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderGreen),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: lightGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on_outlined,
                        color: darkGreen,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '目前點數',
                            style: TextStyle(
                              fontSize: 13,
                              color: subText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.watch<UserProvider>().jPts} J-Pts',
                            style: const TextStyle( // 但裡面的 style 不變，所以 style 可以加 const
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              /// 點數方案
              if (_isLoadingPkgs)
                const Center(child: CircularProgressIndicator())
              else
                ..._packages.map((pkg) {
                  final int pts = (pkg['points'] as num).toInt();
                  final int price = (pkg['price'] as num).toInt();
                  final String tag = pkg['tag'] as String? ?? '';
                  final String desc = pkg['description'] as String? ?? '';
                  final String name = pkg['name'] as String? ?? '$pts Points';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PointPackageCard(
                      points: '$pts Points',
                      price: 'NT\$$price',
                      desc: desc,
                      tag: tag,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PointCheckoutScreen(
                            title: name,
                            points: pts,
                            price: price,
                            badge: tag.isEmpty ? null : tag,
                            subtitle: desc,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 8),

              /// Premium 引導卡
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PremiumScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderGreen),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF3D8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: gold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '升級 Premium Pro',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '每月贈送 1000 Points，並解鎖完整分析功能',
                              style: TextStyle(
                                fontSize: 13,
                                color: subText,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: darkGreen,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// J-Pts 商店入口
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PointsStoreScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB8C8F0)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFDDE8FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.storefront_outlined, color: Color(0xFF3B69CC), size: 24),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('J-Pts 商店', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                            SizedBox(height: 4),
                            Text('用點數換取加購次數或永久擴充', style: TextStyle(fontSize: 13, color: subText)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF3B69CC)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// 付款方式
              const Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _paymentCard(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.android, size: 22, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Google Pay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _paymentCard(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card, size: 22, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '信用卡',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 交易紀錄
              const Text(
                '交易紀錄',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingTxn)
                const Center(child: CircularProgressIndicator())
              else if (_transactions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderGreen),
                  ),
                  child: const Center(
                    child: Text(
                      '尚無交易紀錄',
                      style: TextStyle(color: subText, fontSize: 14),
                    ),
                  ),
                )
              else
                ..._transactions.map((txn) {
                  final type = txn['transaction_type'] ?? 'purchase';
                  final pts = txn['points'] as int? ?? 0;
                  final isSpend = type == 'spend';
                  final isGrant = type == 'subscription_grant' || type == 'reward';

                  IconData icon;
                  Color iconColor;
                  if (isSpend) {
                    icon = Icons.remove_circle_outline;
                    iconColor = Colors.red;
                  } else if (isGrant) {
                    icon = Icons.card_membership;
                    iconColor = const Color(0xFFC6A700);
                  } else {
                    icon = Icons.monetization_on_outlined;
                    iconColor = darkGreen;
                  }

                  final ptsLabel = pts >= 0 ? '+$pts J-Pts' : '$pts J-Pts';
                  final ptsColor = isSpend ? Colors.red : darkGreen;
                  final feature = txn['related_feature'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderGreen),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ptsLabel,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ptsColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                feature != null
                                    ? '$feature • ${txn['created_at']}'
                                    : '${txn['payment_method']} • ${txn['created_at']}',
                                style: const TextStyle(
                                    fontSize: 12, color: subText),
                              ),
                            ],
                          ),
                        ),
                        if (!isSpend && !isGrant)
                          Text(
                            '\$${txn['price']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGreen),
      ),
      child: child,
    );
  }
}

class _PointPackageCard extends StatelessWidget {
  final String points;
  final String price;
  final String desc;
  final String tag;
  final VoidCallback onTap;

  const _PointPackageCard({
    required this.points,
    required this.price,
    required this.desc,
    required this.tag,
    required this.onTap,
  });

  static const Color primaryGreen = Color(0xFF8FB98B);
  static const Color darkGreen = Color(0xFF5F8F5B);
  static const Color lightGreen = Color(0xFFE8F0DD);
  static const Color borderGreen = Color(0xFFD4E1C8);
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF7A7A7A);
  static const Color gold = Color(0xFFF0B84B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFD4E4B9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          points,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        if (tag.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: gold,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 13,
                        color: subText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text(
                '立即購買',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/premium/premium_screen.dart';

class BuyPointsScreen extends StatelessWidget {
  const BuyPointsScreen({Key? key}) : super(key: key);

  static const Color _cardBg = Color(0xFFE3ECD1);
  static const Color _iconBg = Color(0xFFC9DDA8);
  static const Color _buyBtnColor = Color(0xFF8CB481);
  static const Color _upgradeBtnColor = Color(0xFF93BC92);
  static const Color _textDark = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    const packages = [
      {'points': '500 Points', 'price': '\$50'},
      {'points': '1200 Points', 'price': '\$100'},
      {'points': '3000 Points', 'price': '\$200'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 24, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Buy Points',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 18),

              ...packages.map(
                (pkg) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PointPackageCard(
                    points: pkg['points']!,
                    price: pkg['price']!,
                    onBuy: () {
                      // 之後串金流再補
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _upgradeBtnColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '升級Premium Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: const [
                  _PaymentMethodCard(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.apple, size: 22, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          'Pay',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  _PaymentMethodCard(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card, size: 22, color: Color(0xFF3778C8)),
                        SizedBox(width: 6),
                        Text(
                          '信用卡',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointPackageCard extends StatelessWidget {
  final String points;
  final String price;
  final VoidCallback onBuy;

  const _PointPackageCard({
    required this.points,
    required this.price,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: BuyPointsScreen._cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: BuyPointsScreen._iconBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  points,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BuyPointsScreen._textDark,
                  ),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: BuyPointsScreen._textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: BuyPointsScreen._buyBtnColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Buy Now',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final Widget child;

  const _PaymentMethodCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7E1CC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: child),
    );
  }
}
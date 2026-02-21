import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class BuyPointsScreen extends StatelessWidget {
  const BuyPointsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final packages = [
      {'points': '500 Points', 'price': '\$50'},
      {'points': '1200 Points', 'price': '\$100'},
      {'points': '3000 Points', 'price': '\$200'},
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Buy Points', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 20),
              ...packages.map((pkg) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        child: Icon(Icons.monetization_on, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(pkg['points']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                      Text(pkg['price']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Buy Now', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 20),
              const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.primaryLighter), borderRadius: BorderRadius.circular(8)),
                  child: const Text('🍎 Apple Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.primaryLighter), borderRadius: BorderRadius.circular(8)),
                  child: const Text('💳 信用卡', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

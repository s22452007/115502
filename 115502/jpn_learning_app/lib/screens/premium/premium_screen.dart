import 'package:flutter/material.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int selectedPlanIndex = 0;

  final List<Map<String, String>> plans = [
    {'price': '\$490/月'},
    {'price': '\$990/年'},
  ];

  final List<Map<String, String>> pointPackages = [
    {'points': '500 Points', 'price': '\$50'},
    {'points': '1200 Points', 'price': '\$100'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 26,
                          color: Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  /// 表格
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5EBD9)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Expanded(
                                child: _PlanHeader(
                                  title: 'Free Plan',
                                  isLeft: true,
                                ),
                              ),
                              Expanded(
                                child: _PlanHeader(
                                  title: 'Premium Pro',
                                  isLeft: false,
                                ),
                              ),
                            ],
                          ),
                          _featureRow(
                            '使用十分鐘\n看一次廣告',
                            '無限使用\n無需看廣告',
                          ),
                          _featureRow(
                            '每天最多三次\n與AI機器人聊天',
                            '無限次數\n與AI機器人聊天',
                          ),
                          _featureRow(
                            '每天最多三次\n上傳場景照片',
                            '無限次數\n上傳場景照片',
                          ),
                          _featureRow(
                            '',
                            '詳細分析學習結果',
                          ),
                          _featureRow(
                            '',
                            '每月贈\n1000 Points',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  /// 價格卡
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(plans.length, (index) {
                        final item = plans[index];
                        final bool isSelected = selectedPlanIndex == index;

                        return Padding(
                          padding: EdgeInsets.only(right: index == 0 ? 14 : 0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedPlanIndex = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 150,
                              height: 74,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFA6BC74)
                                    : const Color(0xFFC9D9A9),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                item['price']!,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 按鈕
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF69B569),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '開始七天免費試用',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF69B569),
                                width: 1.6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '選擇方案 立即訂閱',
                              style: TextStyle(
                                color: Color(0xFF69B569),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  /// 點數區
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: pointPackages
                          .map(
                            (pkg) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PointPackageCard(
                                points: pkg['points']!,
                                price: pkg['price']!,
                                onTap: () {},
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Payment Methods',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD7E1CC),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.apple, color: Colors.black, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Apple Pay',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD7E1CC),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  color: Color(0xFF3778C8),
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '信用卡',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
    String left,
    String right, {
    bool isLast = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: _PlanCell(
            text: left,
            showRightBorder: true,
            showBottomBorder: !isLast,
          ),
        ),
        Expanded(
          child: _PlanCell(
            text: right,
            showRightBorder: false,
            showBottomBorder: !isLast,
          ),
        ),
      ],
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final String title;
  final bool isLeft;

  const _PlanHeader({
    required this.title,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLeft ? const Color(0xFFCFDDB7) : const Color(0xFFAABE7E),
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? const Radius.circular(16) : Radius.zero,
          topRight: isLeft ? Radius.zero : const Radius.circular(16),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isLeft ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }
}

class _PlanCell extends StatelessWidget {
  final String text;
  final bool showRightBorder;
  final bool showBottomBorder;

  const _PlanCell({
    required this.text,
    required this.showRightBorder,
    required this.showBottomBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: showRightBorder
              ? const BorderSide(color: Color(0xFFE5EBD9))
              : BorderSide.none,
          bottom: showBottomBorder
              ? const BorderSide(color: Color(0xFFE5EBD9))
              : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.25,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _PointPackageCard extends StatelessWidget {
  final String points;
  final String price;
  final VoidCallback onTap;

  const _PointPackageCard({
    required this.points,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAD8)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFDCE8C8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_outlined,
              color: Color(0xFF7C9A68),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              points,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7DB47D),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Buy Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
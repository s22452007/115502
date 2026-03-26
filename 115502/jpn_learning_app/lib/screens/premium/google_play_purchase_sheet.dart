import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

Future<void> showGooglePlayPurchaseSheet({
  required BuildContext context,
  required int points,
  required int price,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GooglePlayPurchaseSheet(
      points: points,
      price: price,
    ),
  );
}

class _GooglePlayPurchaseSheet extends StatefulWidget {
  final int points;
  final int price;

  const _GooglePlayPurchaseSheet({
    required this.points,
    required this.price,
  });

  @override
  State<_GooglePlayPurchaseSheet> createState() =>
      _GooglePlayPurchaseSheetState();
}

class _GooglePlayPurchaseSheetState extends State<_GooglePlayPurchaseSheet> {
  bool isLoading = false;

  static const Color deepText = Color(0xFF202124);
  static const Color subText = Color(0xFF5F6368);
  static const Color borderColor = Color(0xFFE0E3E7);
  static const Color green = Color(0xFF34A853);
  static const Color bg = Colors.white;

  Future<void> _handlePurchase() async {
    setState(() {
      isLoading = true;
    });

    final userId = context.read<UserProvider>().userId;

    if (userId == null) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能購買喔！')),
      );
      return;
    }

    final result = await ApiClient.buyPoints(userId, widget.points);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result.containsKey('total_points')) {
      context.read<UserProvider>().setJPts(result['total_points']);

      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '購買成功',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: deepText,
              ),
            ),
            content: Text(
              '你已成功購買 ${widget.points} J-Pts，點數已加入帳戶。',
              style: const TextStyle(
                color: subText,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // close dialog
                  Navigator.pop(context); // close checkout page
                },
                child: const Text(
                  '完成',
                  style: TextStyle(
                    color: green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? '購買失敗')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADCE0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.android, color: green, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Google Pay',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: deepText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  child: Column(
                    children: [
                      _infoRow(
                        label: '商品',
                        value: '${widget.points} J-Pts',
                      ),
                      const SizedBox(height: 14),
                      _infoRow(
                        label: '價格',
                        value: '\$${widget.price}',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    children: const [
                      _PaymentRow(
                        icon: Icons.account_circle_outlined,
                        title: 'Google 帳號',
                        subtitle: 'eric.demo@gmail.com',
                      ),
                      SizedBox(height: 14),
                      _PaymentRow(
                        icon: Icons.credit_card_outlined,
                        title: '付款方式',
                        subtitle: 'Visa •••• 1234',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Text(
                    '你的付款資訊會由 Google 安全處理。',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: subText,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '購買  \$${widget.price}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: subText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            color: deepText,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PaymentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const Color deepText = Color(0xFF202124);
  static const Color subText = Color(0xFF5F6368);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: subText, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: deepText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: subText,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: subText,
          size: 22,
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'credit_card_payment_screen.dart';
import 'google_play_purchase_sheet.dart';

class PointCheckoutScreen extends StatefulWidget {
  final String title;
  final int points;
  final int price;
  final String? badge;
  final String? subtitle;

  const PointCheckoutScreen({
    super.key,
    required this.title,
    required this.points,
    required this.price,
    this.badge,
    this.subtitle,
  });

  @override
  State<PointCheckoutScreen> createState() => _PointCheckoutScreenState();
}

class _PointCheckoutScreenState extends State<PointCheckoutScreen> {
  String selectedPayment = 'google_play';

  static const Color bgColor = Color(0xFFF8F8F8);
  static const Color cardGreen = Color(0xFFEAF0E2);
  static const Color softGreen = Color(0xFFDCE8CC);
  static const Color primaryGreen = Color(0xFF8CB383);
  static const Color deepText = Color(0xFF333333);
  static const Color subText = Color(0xFF777777);
  static const Color badgeColor = Color(0xFFF2B84B);

  String get _bottomButtonText {
    switch (selectedPayment) {
      case 'card':
        return '前往安全付款  \$${widget.price}';
      case 'google_play':
      default:
        return '前往 Google Pay  \$${widget.price}';
    }
  }

  void _handleCheckout() {
    if (selectedPayment == 'card') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreditCardPaymentScreen(
            points: widget.points,
            price: widget.price,
          ),
        ),
      );
    } else {
      showGooglePlayPurchaseSheet(
        context: context,
        points: widget.points,
        price: widget.price,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: deepText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '確認購買',
          style: TextStyle(
            color: deepText,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: bgColor,
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _handleCheckout,
              child: Text(
                _bottomButtonText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildCurrentPlanCard(),
          const SizedBox(height: 18),
          _buildPaymentCard(),
          const SizedBox(height: 18),
          _buildSummaryCard(),
          const SizedBox(height: 18),
          _buildNoticeCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E4CC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_outlined,
              color: primaryGreen,
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
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: deepText,
                      ),
                    ),
                    if (widget.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle ?? '購買後將立即加入你的帳戶',
                  style: const TextStyle(
                    fontSize: 14,
                    color: subText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.points} J-Pts',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: deepText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${widget.price}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '付款方式',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '推薦付款方式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          _paymentOption(
            value: 'google_pay',
            title: 'Google Pay',
            subtitle: '由 Google Pay 安全處理付款',
            icon: Icons.android,
          ),
          const SizedBox(height: 16),
          const Text(
            '其他付款方式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          _paymentOption(
            value: 'card',
            title: '信用卡 / 簽帳金融卡',
            subtitle: 'Visa、MasterCard、JCB｜由第三方支付平台安全處理',
            icon: Icons.credit_card,
          ),
          const SizedBox(height: 16),
          _buildSecurityNotice(),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = selectedPayment == value;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          selectedPayment = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF4F8EE)
              : Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFD5DEC8),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(icon, color: primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: deepText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: subText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: selectedPayment,
              activeColor: primaryGreen,
              onChanged: (v) {
                setState(() {
                  selectedPayment = v!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD5DEC8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            color: primaryGreen,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '安全付款說明',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: deepText,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '付款資訊將由第三方支付平台處理，本系統不會儲存您的完整卡片資料。',
                  style: TextStyle(
                    color: subText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '訂單摘要',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
          const SizedBox(height: 16),
          _summaryRow('商品金額', '\$${widget.price}'),
          const SizedBox(height: 10),
          _summaryRow('手續費', '\$0'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: Color(0xFFD2DDC3),
            ),
          ),
          _summaryRow(
            '總計',
            '\$${widget.price}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: bold ? deepText : subText,
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: deepText,
            fontSize: bold ? 20 : 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DFB0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '購買說明',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '• 購買完成後，J-Pts 會立即加入你的帳戶。\n'
            '• 點數可用於解鎖更多學習互動與分析功能。\n'
            '• 付款流程將由對應平台處理，提升付款安全性。\n'
            '• 付款成功後恕不退款，請再次確認購買內容。',
            style: TextStyle(
              color: subText,
              fontSize: 13.5,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
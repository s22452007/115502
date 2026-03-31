import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class CreditCardPaymentScreen extends StatefulWidget {
  final int points;
  final int price;

  const CreditCardPaymentScreen({
    super.key,
    required this.points,
    required this.price,
  });

  @override
  State<CreditCardPaymentScreen> createState() =>
      _CreditCardPaymentScreenState();
}

class _CreditCardPaymentScreenState extends State<CreditCardPaymentScreen> {
  bool _isSubmitting = false;

  static const Color bgColor = Color(0xFFF8F8F8);
  static const Color cardGreen = Color(0xFFEAF0E2);
  static const Color borderGreen = Color(0xFFD9E4CC);
  static const Color primaryGreen = Color(0xFF8CB383);
  static const Color softGreen = Color(0xFFDCE8CC);
  static const Color deepText = Color(0xFF333333);
  static const Color subText = Color(0xFF777777);

  Future<void> _handleSubmit() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能購買喔！')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await ApiClient.buyPoints(
      userId, widget.points,
      price: widget.price,
      paymentMethod: '信用卡',
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result.containsKey('total_points')) {
      context.read<UserProvider>().setJPts(result['total_points']);
      _showPaymentSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? '購買失敗')),
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
          '安全付款',
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
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '前往第三方安全付款  \$${widget.price}',
                      style: const TextStyle(
                        color: Colors.white,
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
          _buildOrderCard(),
          const SizedBox(height: 18),
          _buildSecurityCard(),
          const SizedBox(height: 18),
          _buildProcessCard(),
          const SizedBox(height: 18),
          _buildNoticeCard(),
        ],
      ),
    );
  }

  Widget _buildOrderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.credit_card,
              color: primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '信用卡 / 簽帳金融卡',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: deepText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '購買 ${widget.points} J-Pts',
                  style: const TextStyle(
                    fontSize: 14,
                    color: subText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${widget.price}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderGreen),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: primaryGreen,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                '付款安全說明',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: deepText,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            '付款將由第三方支付平台處理',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: deepText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '本系統不會儲存您的完整卡片資訊。',
            style: TextStyle(
              fontSize: 14,
              color: subText,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '支援卡別：Visa、MasterCard、JCB',
            style: TextStyle(
              fontSize: 14,
              color: subText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderGreen),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '付款流程',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
          SizedBox(height: 14),
          _StepItem(
            step: '1',
            text: '點擊下方按鈕，前往第三方安全付款頁面',
          ),
          SizedBox(height: 12),
          _StepItem(
            step: '2',
            text: '完成付款驗證後，系統會處理本次交易',
          ),
          SizedBox(height: 12),
          _StepItem(
            step: '3',
            text: '付款成功後，J-Pts 會加入你的帳戶',
          ),
        ],
      ),
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
            '提醒',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '• 此頁面僅作為安全付款流程說明。\n'
            '• 若後續正式串接第三方金流，可於按鈕動作中接入付款平台。\n'
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

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            '付款成功',
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
                Navigator.pop(context); // dialog
                Navigator.pop(context); // credit card page
                Navigator.pop(context); // checkout page
              },
              child: const Text(
                '完成',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepItem extends StatelessWidget {
  final String step;
  final String text;

  const _StepItem({
    required this.step,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF8CB383),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF777777),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
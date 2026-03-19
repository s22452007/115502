import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class CreditCardPaymentScreen extends StatefulWidget {
  final int points;
  final int price;

  const CreditCardPaymentScreen({
    Key? key,
    required this.points,
    required this.price,
  }) : super(key: key);

  @override
  State<CreditCardPaymentScreen> createState() =>
      _CreditCardPaymentScreenState();
}

class _CreditCardPaymentScreenState extends State<CreditCardPaymentScreen> {
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  static const Color bgColor = Color(0xFFF8F8F8);
  static const Color cardGreen = Color(0xFFEAF0E2);
  static const Color borderGreen = Color(0xFFD9E4CC);
  static const Color primaryGreen = Color(0xFF8CB383);
  static const Color softGreen = Color(0xFFDCE8CC);
  static const Color deepText = Color(0xFF333333);
  static const Color subText = Color(0xFF777777);

  @override
  void dispose() {
    cardNumberController.dispose();
    nameController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    super.dispose();
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
          '信用卡付款',
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
              onPressed: () async {
                final userId = context.read<UserProvider>().userId;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入才能購買喔！')),
                  );
                  return;
                }

                final result = await ApiClient.buyPoints(userId, widget.points);

                if (!context.mounted) return;

                if (result.containsKey('total_points')) {
                  context.read<UserProvider>().setJPts(result['total_points']);
                  _showPaymentSuccessDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['error'] ?? '購買失敗')),
                  );
                }
              },
              child: Text(
                '確認付款  \$${widget.price}',
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
          _buildCardForm(),
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
                  '信用卡付款',
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

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '請輸入卡片資訊',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: deepText,
            ),
          ),
          const SizedBox(height: 16),
          _buildInputLabel('卡號'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: cardNumberController,
            hintText: '1234 5678 9012 3456',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _buildInputLabel('持卡人姓名'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: nameController,
            hintText: '請輸入姓名',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('到期日'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: expiryController,
                      hintText: 'MM/YY',
                      keyboardType: TextInputType.datetime,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('CVV'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: cvvController,
                      hintText: '123',
                      keyboardType: TextInputType.number,
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: deepText,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0x73333333), // 半透明提示字
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  bool _isSubmitting = false;

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

  String _cardDigitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String? _validateCardNumber(String? value) {
    final digits = _cardDigitsOnly(value ?? '');

    if (digits.isEmpty) {
      return '請輸入卡號';
    }
    if (digits.length < 16) {
      return '卡號未輸入完整';
    }
    if (digits.length > 16) {
      return '卡號格式錯誤';
    }
    return null;
  }

  String? _validateName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '請輸入持卡人姓名';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return '請輸入到期日';
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(text)) {
      return '請輸入正確格式 MM/YY';
    }

    final parts = text.split('/');
    final month = int.tryParse(parts[0]);
    final yearShort = int.tryParse(parts[1]);

    if (month == null || yearShort == null) {
      return '到期日格式錯誤';
    }
    if (month < 1 || month > 12) {
      return '月份需介於 01~12';
    }

    final year = 2000 + yearShort;
    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0);

    if (expiryDate.isBefore(DateTime(now.year, now.month, 1))) {
      return '卡片已過期';
    }

    return null;
  }

  String? _validateCvv(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return '請輸入 CVV';
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(text)) {
      return 'CVV 格式錯誤';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

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

    final result = await ApiClient.buyPoints(userId, widget.points);

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
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildOrderCard(),
            const SizedBox(height: 18),
            _buildCardForm(),
          ],
        ),
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
            validator: _validateCardNumber,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              CardNumberInputFormatter(),
            ],
          ),
          const SizedBox(height: 14),
          _buildInputLabel('持卡人姓名'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: nameController,
            hintText: '請輸入姓名',
            validator: _validateName,
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
                      keyboardType: TextInputType.number,
                      validator: _validateExpiry,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        ExpiryDateInputFormatter(),
                      ],
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
                      validator: _validateCvv,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
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
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: deepText,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0x73333333),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          color: Colors.redAccent,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
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

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final isNotLast = i != digits.length - 1;
      if ((i + 1) % 4 == 0 && isNotLast) {
        buffer.write(' ');
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = digits;

    if (digits.length >= 3) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/password_policy.dart';
import 'package:jpn_learning_app/widgets/common/password_strength_meter.dart';

/// 忘記密碼：先寄驗證碼到註冊信箱，再輸入驗證碼與新密碼。
/// 原本只要輸入 Email 就能直接改密碼，任何人都能改掉別人的密碼。
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;   // 寄出後才顯示驗證碼與新密碼欄位
  bool _sending = false;
  bool _submitting = false;
  int _cooldown = 0;        // 幾秒後才能重寄
  Timer? _timer;

  void _showMessage(String text, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('請先輸入註冊的 Email');
      return;
    }

    setState(() => _sending = true);
    final result = await ApiClient.sendResetCode(email);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.containsKey('message')) {
      setState(() => _codeSent = true);
      _startCooldown(60);
      _showMessage(result['message'], color: Colors.green);
    } else {
      final retryAfter = (result['retry_after'] as num?)?.toInt();
      if (retryAfter != null) _startCooldown(retryAfter);
      _showMessage(result['error'] ?? '驗證碼寄送失敗', color: Colors.red);
    }
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 防呆檢查
    if (email.isEmpty || code.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('所有欄位都必須填寫喔！');
      return;
    }

    final pwError = PasswordPolicy.validate(newPassword, account: email);
    if (pwError != null) {
      _showMessage(pwError);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('兩次輸入的新密碼不相同！');
      return;
    }

    setState(() => _submitting = true);
    final result = await ApiClient.resetPassword(email, code, newPassword);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.containsKey('message')) {
      _showMessage(result['message'], color: Colors.green);
      // 成功後，自動回到登入頁面
      Navigator.pop(context);
    } else {
      _showMessage(result['error'] ?? '重設失敗', color: Colors.red);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_sending && _cooldown <= 0;
    final sendLabel = _sending
        ? '寄送中...'
        : _cooldown > 0
            ? '重新寄送（$_cooldown 秒）'
            : (_codeSent ? '重新寄送驗證碼' : '寄送驗證碼');

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text('重設密碼', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '忘記密碼了嗎？\n請輸入註冊的 Email，我們會寄一組驗證碼給你，輸入驗證碼後就能設定新密碼。',
                style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 32),

              _buildInputField(
                controller: _emailController,
                labelText: '註冊的 Email',
                hintText: '請輸入電子郵件',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: canSend ? _sendCode : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  side: BorderSide(color: canSend ? AppColors.primary : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(sendLabel,
                    style: TextStyle(
                        color: canSend ? AppColors.primary : Colors.grey, fontWeight: FontWeight.bold)),
              ),

              if (_codeSent) ...[
                const SizedBox(height: 24),
                _buildInputField(
                  controller: _codeController,
                  labelText: '驗證碼',
                  hintText: '請輸入信箱收到的 6 位數驗證碼',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                _buildInputField(
                  controller: _newPasswordController,
                  labelText: '新密碼',
                  hintText: '請輸入新密碼',
                  obscureText: true,
                ),
                PasswordStrengthMeter(
                  controller: _newPasswordController,
                  accountController: _emailController,
                ),
                const SizedBox(height: 16),

                _buildInputField(
                  controller: _confirmPasswordController,
                  labelText: '確認新密碼',
                  hintText: '請再次輸入新密碼',
                  obscureText: true,
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _submitting ? null : _submitReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_submitting ? '重設中...' : '確認重設',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

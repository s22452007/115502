import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/password_policy.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/widgets/common/password_strength_meter.dart';
import 'package:jpn_learning_app/screens/auth/welcome_screen.dart';

/// 第一次登入強制改密碼。
///
/// 老師建立學生帳號時，帳號和初始密碼都是學號；任何知道學號的人都能登入，
/// 所以學生第一次登入（或被老師重設密碼後）一定要先換掉才能進入 App。
/// [currentPassword] 是剛才登入用的密碼，直接帶過來，學生不用再輸入一次。
class ForceChangePasswordScreen extends StatefulWidget {
  final String currentPassword;
  final String account;
  final bool requireMedium;
  final Widget next;

  const ForceChangePasswordScreen({
    super.key,
    required this.currentPassword,
    required this.account,
    required this.requireMedium,
    required this.next,
  });

  @override
  State<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  Color get _theme => widget.requireMedium ? const Color(0xFF4A90E2) : const Color(0xFF4E8B57);

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final pw = _newCtrl.text;
    final error = PasswordPolicy.validate(pw, account: widget.account, requireMedium: widget.requireMedium);
    if (error != null) return _toast(error);
    if (pw != _confirmCtrl.text) return _toast('兩次輸入的密碼不相同');
    if (pw == widget.currentPassword) return _toast('新密碼不可與目前密碼相同');

    setState(() => _saving = true);
    final result = await ApiClient.changePassword(widget.currentPassword, pw);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['token'] == null) {
      return _toast(result['error']?.toString() ?? '設定失敗，請稍後再試');
    }
    _toast('密碼已更新，下次請使用新密碼登入');
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => widget.next), (route) => false);
  }

  /// 不想現在改：登出並回到版本選擇頁（沒改密碼就不能進入 App）
  void _logout() {
    context.read<UserProvider>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,   // 沒改完密碼不能用返回鍵跳過
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Icon(Icons.lock_reset_rounded, size: 64, color: _theme)),
                    const SizedBox(height: 16),
                    const Text('設定新密碼',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                    const SizedBox(height: 8),
                    const Text(
                      '你的帳號目前使用老師提供的初始密碼，'
                      '為了保護你的作業和學習紀錄，請先設定一組只有你知道的新密碼。',
                      style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    _field(_newCtrl, '新密碼', _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                    PasswordStrengthMeter(
                      controller: _newCtrl,
                      account: widget.account,
                      requireMedium: widget.requireMedium,
                    ),
                    const SizedBox(height: 16),
                    _field(_confirmCtrl, '再次輸入新密碼', _obscureConfirm,
                        () => setState(() => _obscureConfirm = !_obscureConfirm)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _theme,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('確認設定',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : _logout,
                        child: const Text('改用其他帳號登入', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.lock_outline, color: _theme, size: 22),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}

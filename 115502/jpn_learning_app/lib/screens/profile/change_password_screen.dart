import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart'; // 改成你首頁實際路徑

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
 
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('目前沒有登入使用者');
      return;
    }

    final hasPasswordProvider =
        user.providerData.any((provider) => provider.providerId == 'password');

    if (!hasPasswordProvider) {
      _showMessage('此帳號不是使用密碼登入，無法修改密碼');
      return;
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      _showMessage('找不到 Email，無法修改密碼');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());

      if (!mounted) return;
      _goToHomeWithSuccessMessage();
    } on FirebaseAuthException catch (e) {
      String message = '修改密碼失敗';

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = '目前密碼輸入錯誤';
      } else if (e.code == 'weak-password') {
        message = '新密碼強度太弱，請至少設定 6 碼以上';
      } else if (e.code == 'requires-recent-login') {
        message = '登入狀態已過期，請重新登入後再修改密碼';
      } else {
        message = '修改密碼失敗：${e.message ?? e.code}';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('發生未知錯誤：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToHomeWithSuccessMessage() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (newContext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(newContext).showSnackBar(
              const SnackBar(
                content: Text('更改成功'),
                duration: Duration(seconds: 2),
              ),
            );
          });
          return const HomeScreen();
        },
      ),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密碼'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: '目前密碼',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入目前密碼';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: '新密碼',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入新密碼';
                    }
                    if (value.trim().length < 6) {
                      return '密碼至少要 6 碼';
                    }
                    if (value.trim() == _currentPasswordController.text.trim()) {
                      return '新密碼不能和舊密碼相同';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: '確認新密碼',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請再次輸入新密碼';
                    }
                    if (value.trim() != _newPasswordController.text.trim()) {
                      return '兩次輸入的新密碼不一致';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('確認修改'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
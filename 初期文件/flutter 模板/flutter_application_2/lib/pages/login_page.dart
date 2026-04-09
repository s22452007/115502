import 'package:flutter/material.dart';
import '../model/logistic_regression_mnist.dart';
import '../model/cat_dog_classifier.dart';
import 'camera_digit_page.dart';
import 'cat_dog_page.dart';

class LoginPage extends StatefulWidget {
  final LogisticRegressionMNIST mnistModel;
  final CatDogClassifier catDogModel;

  const LoginPage({
    super.key,
    required this.mnistModel,
    required this.catDogModel,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 驗證表單並導航到指定頁面
  void _navigateToPage(Widget page, String pageName) {
    // 驗證帳號密碼是否都有輸入
    if (_usernameController.text.trim().isEmpty) {
      _showError('請輸入帳號');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showError('請輸入密碼');
      return;
    }

    // 導航到選擇的頁面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => page,
      ),
    );

    // 顯示歡迎訊息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('歡迎 ${_usernameController.text}！進入$pageName'),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 顯示錯誤訊息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple[400]!,
              Colors.deepPurple[700]!,
              Colors.indigo[900]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / 標題區域
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.android_outlined,
                        size: 80,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'AI 圖片辨識系統',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '請登錄以開始使用',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 50),

                    // 登錄表單卡片
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 帳號輸入框
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: '帳號',
                              hintText: '請輸入帳號',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),

                          // 密碼輸入框
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: '密碼',
                              hintText: '請輸入密碼',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              // 按 Enter 時不做任何事，需要用戶選擇功能
                            },
                          ),
                          const SizedBox(height: 30),

                          // 選擇功能說明文字
                          const Text(
                            '請選擇要使用的功能：',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 數字辨識按鈕
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _navigateToPage(
                                  CameraDigitPage(model: widget.mnistModel),
                                  '手寫數字辨識',
                                );
                              },
                              icon: const Icon(Icons.dialpad, size: 24),
                              label: const Text(
                                '手寫數字辨識 (0-9)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 貓狗辨識按鈕
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _navigateToPage(
                                  CatDogPage(model: widget.catDogModel),
                                  '貓狗圖片辨識',
                                );
                              },
                              icon: const Icon(Icons.pets, size: 24),
                              label: const Text(
                                '貓狗圖片辨識 🐱🐶',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 底部提示文字
                    Text(
                      '提示：輸入任意帳號密碼即可登入',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
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
}

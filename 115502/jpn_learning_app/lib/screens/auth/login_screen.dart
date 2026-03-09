import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';

// 因為需要切換「登入」與「註冊」狀態，還有接收輸入框的文字，所以要改成 StatefulWidget
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 控制「目前是登入還是註冊模式」的開關 (預設為 true = 登入模式)
  bool _isLogin = true;

  // 用來抓取使用者輸入的 Email 和密碼
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 執行登入或註冊的按鈕邏輯
  void _submit() {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入 Email 與密碼喔！')),
      );
      return;
    }

    if (_isLogin) {
      // TODO: 之後這裡要呼叫 AuthProvider 進行【登入】API 串接
      print('執行登入 -> Email: $email, PW: $password');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入成功！準備選擇程度...')),
      );
    } else {
      // TODO: 之後這裡要呼叫 AuthProvider 進行【註冊】API 串接
      print('執行註冊 -> Email: $email, PW: $password');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊成功！歡迎加入，準備選擇程度...')),
      );
    }

    // 成功後，跳轉到程度選擇畫面
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // AppColors.white
      body: SafeArea(
        child: SingleChildScrollView( // 加上這個讓小螢幕手機鍵盤彈出時不會破版
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Logo 區塊
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1), // AppColors.primaryLighter
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.camera_alt, size: 60, color: Colors.green), // 暫時代替 logo.png
              ),
              const SizedBox(height: 40),

              // --- Email 輸入框 ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // --- Password 輸入框 ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Password', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true, // 密碼遮蔽
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),

              // --- 登入 / 註冊 主要按鈕 ---
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800], // 依照設計圖是深綠色
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _isLogin ? 'Login' : 'Sign Up',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              
              // --- 切換 登入/註冊 模式的文字按鈕 ---
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin; // 點擊後反轉狀態
                  });
                },
                child: Text(
                  _isLogin ? '還沒有帳號嗎？點此註冊' : '已經有帳號了？點此登入',
                  style: const TextStyle(color: Colors.green, decoration: TextDecoration.underline),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Google 登入按鈕
              OutlinedButton.icon(
                onPressed: () => print('觸發 Google 登入邏輯'),
                icon: const Icon(Icons.g_mobiledata, size: 36, color: Colors.black87),
                label: const Text('Sign in with Google', style: TextStyle(color: Colors.black87, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 16),

              // Apple 登入按鈕
              OutlinedButton.icon(
                onPressed: () => print('觸發 Apple 登入邏輯'),
                icon: const Icon(Icons.apple, size: 28, color: Colors.black87),
                label: const Text('Sign in with Apple', style: TextStyle(color: Colors.black87, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),

              const SizedBox(height: 24),

              // 訪客登入按鈕
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
                  );
                },
                child: const Text(
                  '訪客登入 (Continue as Guest)',
                  style: TextStyle(color: Colors.grey, fontSize: 16, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
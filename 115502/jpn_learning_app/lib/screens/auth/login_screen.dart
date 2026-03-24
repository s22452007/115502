// 1. Flutter 官方套件
import 'package:flutter/material.dart';

// 2. 第三方套件
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 3. 我們自己寫的工具與狀態管理
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/services/auth_service.dart';

// 4. 我們自己寫的畫面 (跳轉用)
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/auth/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入 Email 與密碼喔！')),
      );
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('兩次輸入的密碼不相同喔！')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isLogin ? '登入中...' : '註冊中...')),
    );

    if (_isLogin) {
      final result = await ApiClient.login(email, password);

      if (!context.mounted) return;

      if (result.containsKey('user_id')) {
        context.read<UserProvider>().setUserId(_toInt(result['user_id']));
        context.read<UserProvider>().setEmail(email);

        if (result.containsKey('avatar') &&
            result['avatar'] != null &&
            result['avatar'].toString().isNotEmpty) {
          context.read<UserProvider>().setAvatar(result['avatar']);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登入成功！')),
        );

        if (result.containsKey('streak_days')) {
          context
              .read<UserProvider>()
              .setStreakDays(_toInt(result['streak_days'], defaultValue: 1));
        }
        if (result.containsKey('j_pts')) {
          context.read<UserProvider>().setJPts(_toInt(result['j_pts']));
        }
        if (result.containsKey('daily_scans')) {
          context
              .read<UserProvider>()
              .setDailyScans(_toInt(result['daily_scans']));
        }
        if (result.containsKey('friend_id') && result['friend_id'] != null) {
          context.read<UserProvider>().setFriendId(result['friend_id']);
        }

        if (result['japanese_level'] != null) {
          context
              .read<UserProvider>()
              .setJapaneseLevel(result['japanese_level']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '登入失敗')),
        );
      }
    } else {
      final result = await ApiClient.register(email, password);

      if (!context.mounted) return;

      if (result.containsKey('user_id')) {
        context.read<UserProvider>().setUserId(_toInt(result['user_id']));
        context.read<UserProvider>().setEmail(email);

        if (result.containsKey('friend_id') && result['friend_id'] != null) {
          context.read<UserProvider>().setFriendId(result['friend_id']);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('註冊成功！請選擇您的日語程度')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '註冊失敗')),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 登入中...')),
      );

      // 1. 先做 Firebase Google 登入
      final UserCredential? userCredential =
          await AuthService().signInWithGoogle();

      if (!context.mounted) return;

      final user = userCredential?.user;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 登入失敗，未取得使用者資料')),
        );
        return;
      }

      final email = user.email;
      final avatar = user.photoURL;

      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 帳號未提供 Email')),
        );
        return;
      }

      // 2. Firebase 登入成功後，打你同學的 Flask API
      final result = await ApiClient.googleLogin(
        email,
        avatar: avatar,
      );

      if (!context.mounted) return;

      if (!result.containsKey('user_id')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Google 登入同步失敗')),
        );
        return;
      }

      // 3. 存進 UserProvider（使用你們自己後端的會員資料）
      context.read<UserProvider>().setUserId(_toInt(result['user_id']));
      context.read<UserProvider>().setEmail(email);

      if (result.containsKey('friend_id') && result['friend_id'] != null) {
        context.read<UserProvider>().setFriendId(result['friend_id']);
      }

      if (result.containsKey('avatar') &&
          result['avatar'] != null &&
          result['avatar'].toString().isNotEmpty) {
        context.read<UserProvider>().setAvatar(result['avatar']);
      } else if (avatar != null && avatar.isNotEmpty) {
        context.read<UserProvider>().setAvatar(avatar);
      }

      if (result.containsKey('streak_days')) {
        context
            .read<UserProvider>()
            .setStreakDays(_toInt(result['streak_days'], defaultValue: 1));
      } else {
        context.read<UserProvider>().setStreakDays(1);
      }

      if (result.containsKey('j_pts')) {
        context.read<UserProvider>().setJPts(_toInt(result['j_pts']));
      } else {
        context.read<UserProvider>().setJPts(0);
      }

      if (result.containsKey('daily_scans')) {
        context
            .read<UserProvider>()
            .setDailyScans(_toInt(result['daily_scans']));
      } else {
        context.read<UserProvider>().setDailyScans(0);
      }

      if (result.containsKey('japanese_level') &&
          result['japanese_level'] != null) {
        context
            .read<UserProvider>()
            .setJapaneseLevel(result['japanese_level']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google 登入成功：${user.displayName ?? email}'),
        ),
      );

      // 4. 導頁：有程度就進首頁，沒有就去選程度
      if (result['japanese_level'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 登入失敗：$e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'JPN Learning ID',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isLogin
                    ? '歡迎使用 JPN Learning App\n請登入您的帳號！'
                    : '歡迎加入 JPN Learning App\n註冊一個新帳號！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              _buildInputField(
                controller: _emailController,
                labelText: 'Email',
                hintText: '電子郵件',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _buildInputField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: '密碼',
                obscureText: true,
              ),
              const SizedBox(height: 16),

              if (!_isLogin) ...[
                _buildInputField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm Password',
                  hintText: '驗證密碼',
                  obscureText: true,
                ),
                const SizedBox(height: 12),
              ],

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '忘記密碼？',
                      style: TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

              if (!_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = true;
                      });
                    },
                    child: const Text(
                      '已有帳號？前往登入',
                      style: TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _isLogin ? '登入' : '註冊',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_isLogin)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = false;
                    });
                  },
                  child: const Text(
                    '還沒有帳號嗎？點此註冊',
                    style: TextStyle(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '使用以下方式登入',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _handleGoogleLogin,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.g_mobiledata,
                          size: 36,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '使用Google登入',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Apple 登入功能開發中')),
                      );
                    },
                    child: Column(
                      children: [
                        const Icon(
                          Icons.apple,
                          size: 28,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '使用Apple登入',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LevelSelectScreen(),
                    ),
                  );
                },
                child: const Text(
                  '訪客登入 (Continue as Guest)',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
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
        Text(
          labelText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 101, 101, 101),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
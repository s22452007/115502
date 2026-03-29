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

  // ============== 您的原始邏輯完全保留 開始 ==============
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入 Email 與密碼喔！')));
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('兩次輸入的密碼不相同喔！')));
      return;
    }

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

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登入成功！')));

        if (result.containsKey('streak_days')) {
          context.read<UserProvider>().setStreakDays(
            _toInt(result['streak_days'], defaultValue: 1),
          );
        }
        if (result.containsKey('j_pts')) {
          context.read<UserProvider>().setJPts(_toInt(result['j_pts']));
        }
        if (result.containsKey('daily_scans')) {
          context.read<UserProvider>().setDailyScans(
            _toInt(result['daily_scans']),
          );
        }
        if (result.containsKey('friend_id') && result['friend_id'] != null) {
          context.read<UserProvider>().setFriendId(result['friend_id']);
        }
        if (result.containsKey('username') && result['username'] != null) {
          context.read<UserProvider>().setUsername(result['username']);
        }

        if (result['japanese_level'] != null) {
          context.read<UserProvider>().setJapaneseLevel(
            result['japanese_level'],
          );
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
      } else if (result['error'] == 'not_registered') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此 Email 尚未註冊，請先註冊帳號')),
        );
        setState(() {
          _isLogin = false;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['error'] ?? '登入失敗')));
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
        if (result.containsKey('username') && result['username'] != null) {
          context.read<UserProvider>().setUsername(result['username']);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('註冊成功！請選擇您的日語程度')));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['error'] ?? '註冊失敗')));
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google 登入中...')));

      // 1. 先做 Firebase Google 登入
      final UserCredential? userCredential = await AuthService()
          .signInWithGoogle();

      if (!context.mounted) return;

      final user = userCredential?.user;

      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google 登入失敗，未取得使用者資料')));
        return;
      }

      final email = user.email;
      final avatar = user.photoURL;

      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google 帳號未提供 Email')));
        return;
      }

      // 2. Firebase 登入成功後，打你同學的 Flask API
      final result = await ApiClient.googleLogin(email, avatar: avatar);

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
        context.read<UserProvider>().setStreakDays(
          _toInt(result['streak_days'], defaultValue: 1),
        );
      } else {
        context.read<UserProvider>().setStreakDays(1);
      }

      if (result.containsKey('j_pts')) {
        context.read<UserProvider>().setJPts(_toInt(result['j_pts']));
      } else {
        context.read<UserProvider>().setJPts(0);
      }

      if (result.containsKey('daily_scans')) {
        context.read<UserProvider>().setDailyScans(
          _toInt(result['daily_scans']),
        );
      } else {
        context.read<UserProvider>().setDailyScans(0);
      }

      if (result.containsKey('japanese_level') &&
          result['japanese_level'] != null) {
        context.read<UserProvider>().setJapaneseLevel(result['japanese_level']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 登入成功：${user.displayName ?? email}')),
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
    } catch (e, stackTrace) {
      debugPrint('=== Google 登入錯誤: $e ===');
      debugPrint('$stackTrace');
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 登入失敗：$e')));
    }
  }
  // ============== 您的原始邏輯完全保留 結束 ==============

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============== 全新打造的現代化 UI ==============
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // 上半部：插圖與表單區塊 (加上 Expanded 以便將底部固定)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 1. 頂部大型插圖區域
                  Container(
                    height: screenHeight * 0.35,
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded, // 改用書本圖示，更有學習感
                              size: 80,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "JPN Learning ID",
                            style: TextStyle(
                              fontSize: 20,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. 表單區域
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLogin ? 'Let\'s get started' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Login to your account'
                              : 'Sign up to start learning',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 輸入框 Email
                        _buildInputField(
                          controller: _emailController,
                          hintText: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // 輸入框 Password
                        _buildInputField(
                          controller: _passwordController,
                          hintText: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                        ),

                        // 註冊時的確認密碼
                        if (!_isLogin) ...[
                          const SizedBox(height: 20),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            hintText: 'Confirm Password',
                            icon: Icons.lock_reset_rounded,
                            obscureText: true,
                          ),
                        ],

                        // 忘記密碼 (只有登入時顯示)
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: AppColors.textGrey),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 20), // 為了註冊排版加點空白

                        const SizedBox(height: 24),

                        // 登入/註冊主按鈕
                        GestureDetector(
                          onTap: _submit,
                          child: Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _isLogin ? 'LOGIN' : 'SIGN UP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // OR 分隔線
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Or continue with',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 第三方登入按鈕區域 (改為圓形質感設計)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialButton(
                              icon: Icons.g_mobiledata,
                              iconSize: 36,
                              onTap: _handleGoogleLogin,
                            ),
                            const SizedBox(width: 24),
                            _buildSocialButton(
                              icon: Icons.apple,
                              iconSize: 28,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Apple 登入功能開發中'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 訪客登入
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LevelSelectScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Continue as Guest',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 下半部：固定的切換註冊/登入區塊 (仿照您的參考圖)
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin
                      ? 'Don\'t have an account? '
                      : 'Already have an account? ',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // 切換狀態，原本是在這裡導航，現在直接用同一個畫面切換
                    setState(() {
                      _isLogin = !_isLogin;
                      // 切換時可以順便清空密碼
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  child: Text(
                    _isLogin ? 'Sign up' : 'Log in',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== 輔助 UI 元件 ==============

  // 1. 現代化圓角輸入框 (不顯示上方 label，只顯示內部 hint 與 icon)
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // 超淡的陰影
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(icon, color: AppColors.primary), // 前方的綠色圖示
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // 2. 第三方登入圓形按鈕
  Widget _buildSocialButton({
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.textDark, // 圖示用深灰色，質感更好
        ),
      ),
    );
  }
}

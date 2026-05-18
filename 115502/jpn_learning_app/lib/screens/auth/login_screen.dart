// 1. Flutter 官方套件
import 'package:flutter/material.dart';

// 2. 第三方套件
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 新增：用於判斷新手引導

// 3. 我們自己寫的工具與狀態管理
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/services/auth_service.dart';
import 'package:jpn_learning_app/services/notification_service.dart';

// 4. 我們自己寫的畫面 (跳轉用)
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/auth/forgot_password_screen.dart';
import 'package:jpn_learning_app/screens/auth/onboarding_screen.dart'; // 新增：新手引導頁面

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

  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _textDark = const Color(0xFF2C3E50);
  final Color _inputFillColor = const Color(0xFFF4F7F5);

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus(); // 畫面初始化時檢查是否需要顯示新手引導
  }

  // 新增：新手引導判斷邏輯
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false); // 標記為已看過
      if (!mounted) return;
      
      // 自動跳轉到新手引導頁面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  // ============== 邏輯部分 (完全保留) ==============
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入 Email 與密碼喔！')));
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('兩次輸入的密碼不相同喔！')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isLogin ? '登入中...' : '註冊中...')));

    if (_isLogin) {
      final result = await ApiClient.login(email, password);
      if (!context.mounted) return;

      if (result.containsKey('user_id')) {
        context.read<UserProvider>().setUserId(_toInt(result['user_id']));
        context.read<UserProvider>().setEmail(email);
        if (result.containsKey('avatar') && result['avatar'] != null && result['avatar'].toString().isNotEmpty) {
          context.read<UserProvider>().setAvatar(result['avatar']);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入成功！歡迎回來，${result['username'] ?? email.split('@')[0]}')));
        if (result.containsKey('streak_days')) context.read<UserProvider>().setStreakDays(_toInt(result['streak_days'], defaultValue: 1));
        if (result.containsKey('j_pts')) context.read<UserProvider>().setJPts(_toInt(result['j_pts']));
        if (result.containsKey('daily_scans')) context.read<UserProvider>().setDailyScans(_toInt(result['daily_scans']));
        if (result.containsKey('friend_id') && result['friend_id'] != null) context.read<UserProvider>().setFriendId(result['friend_id']);
        if (result.containsKey('username') && result['username'] != null) context.read<UserProvider>().setUsername(result['username']);
        if (result.containsKey('is_premium')) context.read<UserProvider>().setIsPremium(result['is_premium'] == true);

        try { await NotificationService.setLoginStatus(true); } catch (e) { debugPrint('推播狀態設定失敗: $e'); }

        if (result['japanese_level'] != null) {
          context.read<UserProvider>().setJapaneseLevel(result['japanese_level']);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? '登入失敗')));
      }
    } else {
      final result = await ApiClient.register(email, password);
      if (!context.mounted) return;
      if (result.containsKey('user_id')) {
        context.read<UserProvider>().setUserId(_toInt(result['user_id']));
        context.read<UserProvider>().setEmail(email);
        if (result.containsKey('friend_id') && result['friend_id'] != null) context.read<UserProvider>().setFriendId(result['friend_id']);
        if (result.containsKey('username') && result['username'] != null) context.read<UserProvider>().setUsername(result['username']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('註冊成功！請選擇您的日語程度')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? '註冊失敗')));
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google 登入中...')));
      final UserCredential? userCredential = await AuthService().signInWithGoogle();
      if (!context.mounted) return;
      final user = userCredential?.user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google 登入失敗，未取得使用者資料')));
        return;
      }
      final email = user.email;
      final avatar = user.photoURL;
      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google 帳號未提供 Email')));
        return;
      }
      final result = await ApiClient.googleLogin(email, avatar: avatar);
      if (!context.mounted) return;
      if (!result.containsKey('user_id')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Google 登入同步失敗')));
        return;
      }
      context.read<UserProvider>().setUserId(_toInt(result['user_id']));
      context.read<UserProvider>().setEmail(email);
      if (result.containsKey('friend_id') && result['friend_id'] != null) context.read<UserProvider>().setFriendId(result['friend_id']);
      if (result.containsKey('avatar') && result['avatar'] != null && result['avatar'].toString().isNotEmpty) {
        context.read<UserProvider>().setAvatar(result['avatar']);
      } else if (avatar != null && avatar.isNotEmpty) {
        context.read<UserProvider>().setAvatar(avatar);
      }
      context.read<UserProvider>().setStreakDays(_toInt(result['streak_days'], defaultValue: 1));
      context.read<UserProvider>().setJPts(_toInt(result['j_pts']));
      context.read<UserProvider>().setDailyScans(_toInt(result['daily_scans']));
      if (result.containsKey('japanese_level') && result['japanese_level'] != null) context.read<UserProvider>().setJapaneseLevel(result['japanese_level']);
      if (result.containsKey('username') && result['username'] != null) context.read<UserProvider>().setUsername(result['username']);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入成功！歡迎回來，${result['username'] ?? email.split('@')[0]}')));
      if (result['japanese_level'] != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google 登入失敗：$e')));
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
    final userProvider = context.watch<UserProvider>();
    final userName = (userProvider.username?.isNotEmpty ?? false) ? userProvider.username : '使用者';

    return Scaffold(
      backgroundColor: _flatCanvasColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
                    child: Column(
                      children: [
                        // 替換點：將 LOGO 放進來，並保留你原本的 Icon 樣式作為防呆
                        Image.asset(
                          'assets/images/logo.png',
                          width: 120, // 調整到適合的大小
                          errorBuilder: (context, error, stackTrace) => Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.menu_book_rounded, size: 70, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "JPN Learning ID",
                          style: TextStyle(fontSize: 20, color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 48),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isLogin ? '早安，$userName!' : '建立新帳號',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _textDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isLogin ? '請登入您的帳號' : '註冊以開始學習之旅',
                            style: const TextStyle(fontSize: 16, color: Colors.black45, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildInputField(
                          controller: _emailController,
                          hintText: '電子郵件',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: _passwordController,
                          hintText: '密碼',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 18),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            hintText: '確認密碼',
                            icon: Icons.lock_reset_rounded,
                            obscureText: true,
                          ),
                        ],

                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: const Text('忘記密碼？', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w700)),
                            ),
                          )
                        else
                          const SizedBox(height: 20),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text(
                              _isLogin ? '登入' : '註冊',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: Colors.black26, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _buildGoogleButton(onTap: _handleGoogleLogin),
                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                          child: const Text(
                            '以訪客身分繼續',
                            style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      border: Border(top: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isLogin ? '還沒有帳號嗎？ ' : '已經有帳號了嗎？ ', style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin ? '立即註冊' : '登入帳號',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black26, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        filled: true,
        fillColor: _inputFillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildGoogleButton({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              "使用 Google 帳號登入",
              style: TextStyle(color: Color(0xFF757575), fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
            const SizedBox(width: 36), 
          ],
        ),
      ),
    );
  }
}
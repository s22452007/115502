import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';
import 'package:jpn_learning_app/screens/auth/welcome_screen.dart';

/// 校園教育版登入頁。
///
/// 跟一般版共用同一支登入 API，差別在帶 portal: 'edu'：
/// 後端只允許學生帳號從這裡登入，一般帳號會被擋下並提示改走一般版。
class EduLoginScreen extends StatefulWidget {
  const EduLoginScreen({Key? key}) : super(key: key);

  @override
  State<EduLoginScreen> createState() => _EduLoginScreenState();
}

class _EduLoginScreenState extends State<EduLoginScreen> {
  // 保持藍色，作為教育版的視覺區隔
  final Color _eduBlue = const Color(0xFF4A90E2);
  final Color _textDark = const Color(0xFF2C3E50);

  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final account = _accountCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final result = await ApiClient.login(account, password, portal: 'edu');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.containsKey('user_id')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? '登入失敗，請稍後再試')),
      );
      return;
    }

    final provider = context.read<UserProvider>();
    provider.setUserId(_toInt(result['user_id']));
    provider.setEmail(account);
    // 一定要記下帳號類型，各畫面靠它決定「不限次數、不顯示加購」
    provider.setAccountType(result['account_type']?.toString());
    if (result['username'] != null) provider.setUsername(result['username']);
    if (result['friend_id'] != null) provider.setFriendId(result['friend_id']);
    if (result['avatar'] != null && result['avatar'].toString().isNotEmpty) {
      provider.setAvatar(result['avatar']);
    }
    provider.setStreakDays(_toInt(result['streak_days'], defaultValue: 1));
    provider.setJPts(_toInt(result['j_pts']));
    provider.setDailyScans(_toInt(result['daily_scans']));

    try {
      await NotificationService.recordLogin();
    } catch (e) {
      debugPrint('推播狀態設定失敗: $e');
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('登入成功！歡迎回到校園模式，${result['username'] ?? account}'),
        backgroundColor: Colors.green,
      ),
    );

    // 跟一般版一樣：還沒選過日文程度的先去選程度
    final level = result['japanese_level'];
    if (level != null) {
      provider.setJapaneseLevel(level.toString());
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // 外部底色
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          // 學生登出後會直接被帶到這一頁，底下沒有上一頁；這時返回鍵改成回版本選擇頁
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        // 👉 1. 建立跟普通版一樣的白色圓角卡片背景
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // 👉 2. 標題與文字全部靠左對齊
                children: [
                  // 👉 3. 頂部 Logo 區塊 (維持置中)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined, size: 70, color: _eduBlue),
                        const SizedBox(height: 8),
                        Text(
                          'Snap to Learn EDU',
                          style: TextStyle(
                            color: _eduBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 標題區塊
                  Text(
                    '早安，同學！',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '請輸入學校提供的帳號與密碼',
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 32),

                  // 輸入框區塊
                  _buildTextField(
                    controller: _accountCtrl,
                    hintText: '帳號',
                    icon: Icons.badge_outlined,
                    validatorMsg: '請輸入帳號',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordCtrl,
                    hintText: '密碼',
                    icon: Icons.lock_outline,
                    validatorMsg: '請輸入密碼',
                    isPassword: true,
                  ),

                  // 👉 4. 忘記密碼 (跟普通版一樣移到按鈕右上方)
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請聯繫您的老師或學校系統管理員重設密碼')),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '忘記密碼？',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 登入按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _eduBlue,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24), // 圓角也對齊普通版的膠囊狀
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '登入',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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

  // 👉 5. 封裝輸入框元件：改成普通版的「灰色底、無邊框」風格
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required String validatorMsg,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      // 帳號框按 Enter 跳到密碼框，密碼框按 Enter 直接登入
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: isPassword ? (_) => _isLoading ? null : _handleLogin() : null,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMsg;
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: _eduBlue, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100, // 👉 設定灰色底
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none, // 👉 拿掉邊框
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}

// 1. Flutter 官方套件
import 'package:flutter/material.dart';

// 2. 第三方套件
import 'package:provider/provider.dart';

// 3. 我們自己寫的工具與狀態管理
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 4. 我們自己寫的畫面 (跳轉用)
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/auth/forgot_password_screen.dart';

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
  final _confirmPasswordController = TextEditingController(); // 註冊模式用

  // 執行登入或註冊的主要按鈕邏輯
  Future<void> _submit() async {
    final email = _emailController.text.trim(); // .trim() 可以清掉多餘空白
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. 防呆檢查
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入 Email 與密碼喔！')),
      );
      return;
    }

    if (!_isLogin) {
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('兩次輸入的密碼不相同喔！')),
        );
        return;
      }
    }

    // 顯示 Loading 提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isLogin ? '登入中...' : '註冊中...')),
    );

    if (_isLogin) {
      // ---------------- 【登入邏輯】 ----------------
      final result = await ApiClient.login(email, password);
      
      if (!context.mounted) return; // 防呆：確保畫面還在

      if (result.containsKey('user_id')) {
        // 登入成功！存下 user_id
        context.read<UserProvider>().setUserId(result['user_id']);
        context.read<UserProvider>().setEmail(email); // 存入輸入的 Email

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登入成功！')),
        );

        // 聰明的判斷：如果後端說他已經測驗過 (有 japanese_level)，就直接去首頁！
        if (result['japanese_level'] != null) {
          context.read<UserProvider>().setJapaneseLevel(result['japanese_level']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // 如果沒有程度，代表是舊帳號但沒測驗過，去測驗選擇頁
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
          );
        }
      } else {
        // 登入失敗 (密碼錯誤或找不到帳號)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '登入失敗')),
        );
      }

    } else {
      // ---------------- 【註冊邏輯】 ----------------
      final result = await ApiClient.register(email, password);
      
      if (!context.mounted) return;

      if (result.containsKey('user_id')) {
        // 註冊成功！存下 user_id
        context.read<UserProvider>().setUserId(result['user_id']);
        context.read<UserProvider>().setEmail(email); // 存入輸入的 Email
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('註冊成功！請選擇您的日語程度')),
        );

        // 新註冊的人一定沒測驗過，帶他去選擇程度
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
        );
      } else {
        // 註冊失敗 (可能 Email 被用過了)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '註冊失敗')),
        );
      }
    }
  }

  @override
  void dispose() {
    // 記得銷毀控制器，釋放記憶體
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
        // 加上 SingleChildScrollView 讓畫面可以滑動，鍵盤彈出時不會 Overflow
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // --- 頂部 Logo 區塊 (依照原本 Container 修改，圖示改為深綠色鎖) ---
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter, // 你的原本專案顏色
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.lock_rounded, 
                  size: 60, 
                  color: AppColors.primary // 你的原本專案綠色
                ), 
              ),
              const SizedBox(height: 32),

              // --- 標題 (使用你的深綠色) ---
              Text(
                'JPN Learning ID', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 24, 
                  color: AppColors.textDark
                )
              ),
              const SizedBox(height: 16),
              Text(
                _isLogin ? '歡迎使用 JPN Learning App\n請登入您的帳號！' : '歡迎加入 JPN Learning App\n註冊一個新帳號！',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 40),

              // --- 輸入框區塊 (模仿範例樣式，顏色改為綠色) ---
              // Email
              _buildInputField(
                controller: _emailController,
                labelText: 'Email',
                hintText: '電子郵件',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password
              _buildInputField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: '密碼',
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // Confirm Password (只有註冊模式顯示)
              if (!_isLogin) ...[
                _buildInputField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm Password',
                  hintText: '驗證密碼',
                  obscureText: true,
                ),
                const SizedBox(height: 12),
              ],

              // --- 條件式顯示的連結 (忘記密碼 / 前往登入) ---
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // 跳轉到忘記密碼畫面
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
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
                        _isLogin = true; // 切換到登入模式
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

              // --- 登入 / 註冊 主要按鈕 (深綠色) ---
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, // 你的專案深綠色
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2, // 加上一點陰影符合範例卡片感
                ),
                child: Text(
                  _isLogin ? '登入' : '註冊',
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // --- 切換 登入/註冊 模式的文字連結 ---
              if (_isLogin)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = false; // 切換到註冊模式
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

              // --- 分隔線 (仿範例樣式) ---
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or', 
                      style: TextStyle(color: Colors.grey.shade500)
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '使用以下方式登入', 
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)
              ),
              const SizedBox(height: 24),

              // --- 第三方登入圖示 (仿範例並排樣式，顏色改為你的綠色) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google 登入
                  GestureDetector(
                    onTap: () => print('觸發 Google 登入邏輯'),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.g_mobiledata, 
                          size: 36, 
                          color: AppColors.primary // 改為你的綠色
                        ),
                        const SizedBox(height: 8),
                        const Text('使用Google登入', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32), // 圖示間距

                  // Apple 登入
                  GestureDetector(
                    onTap: () => print('觸發 Apple 登入邏輯'),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.apple, 
                          size: 28, 
                          color: AppColors.primary // 改為你的綠色
                        ),
                        const SizedBox(height: 8),
                        const Text('使用Apple登入', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- 訪客登入按鈕 (保留原本代碼邏輯) ---
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
                  );
                },
                child: const Text(
                  '訪客登入 (Continue as Guest)',
                  style: TextStyle(
                    color: AppColors.textGrey, 
                    fontSize: 14, 
                    decoration: TextDecoration.underline
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 用來動態生成輸入框的輔助方法
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
            color: Colors.grey.shade700
          )
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade100, // 仿範例的淺灰色背景
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none, // 隱藏外框線
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5), // 聚焦時顯示綠色邊框
            ),
          ),
        ),
      ],
    );
  }
}
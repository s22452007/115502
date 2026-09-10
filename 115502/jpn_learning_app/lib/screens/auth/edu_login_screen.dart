import 'package:flutter/material.dart';


class EduLoginScreen extends StatefulWidget {
  const EduLoginScreen({Key? key}) : super(key: key);

  @override
  State<EduLoginScreen> createState() => _EduLoginScreenState();
}

class _EduLoginScreenState extends State<EduLoginScreen> {
  // 教育版專屬主色調
  final Color _eduBlue = const Color(0xFF4A90E2);

  final _formKey = GlobalKey<FormState>();
  final _schoolCodeCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _schoolCodeCtrl.dispose();
    _studentIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // 觸發表單驗證
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: 這裡未來要替換成呼叫後端 API 的邏輯
    // 模擬網路延遲
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 模擬登入成功，顯示提示並跳轉
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登入成功！歡迎回到校園模式'),
        backgroundColor: Colors.green,
      ),
    );
    // TODO: Navigator.pushReplacement(...) 跳轉到教育版的首頁
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // 與首頁相同的背景色
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // 標題與圖示
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _eduBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school, size: 48, color: _eduBlue),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '校園教育版登入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '請輸入學校代碼與學號進行登入',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // 1. 學校代碼輸入框
                _buildTextField(
                  controller: _schoolCodeCtrl,
                  label: '學校代碼 (School Code)',
                  icon: Icons.account_balance,
                  hintText: '例如：NTUB',
                  validatorMsg: '請輸入學校代碼',
                ),
                const SizedBox(height: 16),

                // 2. 學號輸入框
                _buildTextField(
                  controller: _studentIdCtrl,
                  label: '學號 / 員工編號',
                  icon: Icons.badge,
                  hintText: '請輸入您的學號',
                  validatorMsg: '請輸入學號',
                ),
                const SizedBox(height: 16),

                // 3. 密碼輸入框
                _buildTextField(
                  controller: _passwordCtrl,
                  label: '密碼',
                  icon: Icons.lock,
                  hintText: '請輸入密碼',
                  validatorMsg: '請輸入密碼',
                  isPassword: true,
                ),
                const SizedBox(height: 32),

                // 登入按鈕
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _eduBlue,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
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
                            '登入系統',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 忘記密碼 (教育版通常會請學生聯絡校方)
                Center(
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請聯繫您的學校系統管理員重設密碼')),
                      );
                    },
                    child: const Text(
                      '忘記密碼？請聯繫校方',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 封裝輸入框元件，讓程式碼更乾淨
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    required String validatorMsg,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMsg;
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _eduBlue, width: 2),
        ),
      ),
    );
  }
}
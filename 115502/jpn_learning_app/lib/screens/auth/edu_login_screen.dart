import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/services/auth_service.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/auth/level_select_screen.dart';
import 'package:jpn_learning_app/screens/auth/welcome_screen.dart';
import 'package:jpn_learning_app/screens/auth/force_change_password_screen.dart';

/// 校園教育版登入頁。兩種登入方式：
///
/// 1. 選學校 → 學校 Google 帳號登入（像 TronClass）：後端檢查網域與學號，
///    第一次登入自動建立學生帳號，之後在「我的教室」輸入班級代碼加入班級。
/// 2. 老師貼名單建立的學號帳號：跟一般版共用同一支登入 API，差別在帶 portal: 'edu'，
///    後端只允許學生帳號從這裡登入，一般帳號會被擋下並提示改走一般版。
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

  List<Map<String, dynamic>> _schools = [];
  Map<String, dynamic>? _school; // 選好的學校
  bool _isGoogleLoading = false;
  bool _showPasswordForm = false; // 學號密碼登入的輸入框，按「學號密碼登入」才展開

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  /// 載入學校清單（不預選，每次都讓使用者自己選）
  Future<void> _loadSchools() async {
    final res = await ApiClient.getSchools();
    final list = (res['schools'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    if (!mounted) return;
    setState(() => _schools = list);
  }

  Future<void> _pickSchool() async {
    // 打開登入頁時沒抓到（後端還沒啟動、網路不穩）就再抓一次，不然清單一直是空的
    if (_schools.isEmpty) {
      await _loadSchools();
      if (!mounted) return;
    }
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _SchoolSearchPage(schools: _schools, accent: _eduBlue)),
    );
    if (picked == null || !mounted) return;
    if (picked['add_new'] == true) {
      await _addSchool();
      return;
    }
    setState(() => _school = picked);
  }

  /// 清單裡沒有自己的學校：輸入學校名稱，接著用學校 Google 帳號登入，
  /// 後端拿這個帳號的信箱網域登記學校（只收 .edu.tw），學生不用自己打網域
  Future<void> _addSchool() async {
    // 輸入框的控制器交給對話框自己管：對話框關閉動畫還在跑時就 dispose 會紅畫面
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddSchoolDialog(accent: _eduBlue),
    );
    if (name == null || !mounted) return;
    if (name.isEmpty) {
      _showMessage('請輸入學校名稱');
      return;
    }
    await _handleGoogleLogin(newSchoolName: name);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 用學校 Google 帳號登入。[newSchoolName] 有值代表清單裡沒有這間學校、要順便新增
  Future<void> _handleGoogleLogin({String? newSchoolName}) async {
    final school = newSchoolName == null ? _school : null;
    if (newSchoolName == null && school == null) {
      _showMessage('請先選擇學校');
      return;
    }
    setState(() => _isGoogleLoading = true);
    try {
      final credential = await AuthService()
          .signInWithGoogle(hostedDomain: school?['hd']?.toString());
      final user = credential.user;
      final idToken = await user?.getIdToken();
      if (!mounted) return;
      if (user == null || idToken == null || idToken.isEmpty) {
        _showMessage('Google 登入失敗，無法取得身分憑證');
        return;
      }

      final result = await ApiClient.eduGoogleLogin(
        idToken,
        schoolId: school == null ? null : _toInt(school['school_id']),
        newSchoolName: newSchoolName,
        avatar: user.photoURL,
      );
      if (!mounted) return;
      if (!result.containsKey('user_id')) {
        // 被擋下（選錯學校、用了一般 Gmail…）就登出 Google，下次才能換帳號
        await AuthService().signOutGoogle();
        if (!mounted) return;
        _showMessage(result['error']?.toString() ?? '登入失敗，請稍後再試');
        return;
      }
      await _finishLogin(
        result,
        account: result['email']?.toString() ?? user.email ?? '',
        isNew: result['is_new'] == true,
      );
    } catch (e) {
      if (mounted) _showMessage('Google 登入失敗：$e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

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

    await _finishLogin(result, account: account, password: password);
  }

  /// 兩種登入方式共用：記下登入者資料、登記推播，再決定下一頁。
  /// [password] 只有學號帳號登入才有（強制改密碼要用）；[isNew] 是 Google 第一次登入、還沒加入任何班級。
  Future<void> _finishLogin(
    Map<String, dynamic> result, {
    required String account,
    String? password,
    bool isNew = false,
  }) async {
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
        content: Text(isNew
            ? '帳號建立完成！到「我的教室」輸入老師給的班級代碼就能加入班級'
            : '登入成功！歡迎回到校園模式，${result['username'] ?? account}'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: isNew ? 6 : 4),
      ),
    );

    // 跟一般版一樣：還沒選過日文程度的先去選程度
    final level = result['japanese_level'];
    if (level != null) provider.setJapaneseLevel(level.toString());
    final Widget next = level != null ? const HomeScreen() : const LevelSelectScreen();

    // 老師建立的帳號（初始密碼是老師發的臨時密碼）或被重設過密碼：先設定新密碼才能進入
    final currentPassword = password;
    if (result['must_change_password'] == true && currentPassword != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ForceChangePasswordScreen(
            currentPassword: currentPassword,
            account: account,
            requireMedium: true,   // 學生帳號至少要「中」
            next: next,
          ),
        ),
        (route) => false,
      );
      return;
    }

    if (level != null) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => next), (route) => false);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
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
                  const SizedBox(height: 32),

                  // 跟 TronClass 一樣：選學校 → 學校帳號登入（Google）；老師建立的學號帳號收在第二顆按鈕
                  _buildSchoolTile(),
                  const SizedBox(height: 20),
                  _buildGoogleButton(),
                  const SizedBox(height: 8),
                  // 備用：沒有學校 Google 帳號的學生，用老師在後台建立的帳號（初始密碼是老師發的臨時密碼）
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showPasswordForm = !_showPasswordForm),
                      child: Text(
                        _showPasswordForm ? '收起' : '沒有學校帳號？用老師給的帳號登入',
                        style: TextStyle(color: _eduBlue, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  if (_showPasswordForm) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '帳號是學號，密碼是老師發給你的臨時密碼；第一次登入要換成自己的密碼',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 選學校：外觀跟輸入框一樣，點了跳出可搜尋的學校清單
  Widget _buildSchoolTile() {
    final school = _school;
    final domains = (school?['domains'] as List?)?.join('、') ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isGoogleLoading ? null : _pickSchool,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('學校', style: TextStyle(color: Colors.grey, fontSize: 15)),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    school?['name']?.toString() ?? '請選擇學校',
                    style: TextStyle(
                      color: school == null ? Colors.grey : _textDark,
                      fontSize: 16,
                      fontWeight: school == null ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (domains.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text('用 $domains 的學校信箱登入', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
      ],
    );
  }

  /// 學校帳號登入（Google）：主要按鈕，沒選學校前不能按
  Widget _buildGoogleButton() {
    final enabled = _school != null && !_isGoogleLoading && !_isLoading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? _handleGoogleLogin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _eduBlue,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _school == null ? '先選擇學校' : '學校帳號登入',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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

/// 新增學校：輸入學校名稱，按「下一步」回傳名稱，取消回傳 null
class _AddSchoolDialog extends StatefulWidget {
  final Color accent;

  const _AddSchoolDialog({required this.accent});

  @override
  State<_AddSchoolDialog> createState() => _AddSchoolDialogState();
}

class _AddSchoolDialogState extends State<_AddSchoolDialog> {
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增學校'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(hintText: '學校全名，例如：國立○○科技大學、○○市立○○高中'),
          ),
          const Text(
            '接著用你的學校 Google 帳號登入，系統會用你的學校信箱登記這間學校，之後同學就能直接選。',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(context, _nameCtrl.text.trim()),
          child: Text('下一步', style: TextStyle(color: widget.accent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// 選學校的全螢幕搜尋頁（像 TronClass），選好回傳那間學校
class _SchoolSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> schools;
  final Color accent;

  const _SchoolSearchPage({required this.schools, required this.accent});

  @override
  State<_SchoolSearchPage> createState() => _SchoolSearchPageState();
}

class _SchoolSearchPageState extends State<_SchoolSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 名稱或信箱網域都可以搜（打「ntut」也找得到用 ntut.edu.tw 的學校）
    // 「台」「臺」都找得到（打台北也會出現國立臺北大學）
    String norm(String s) => s.toLowerCase().replaceAll('台', '臺');
    // 注音打到一半（還沒選字）的符號不拿去搜，這時也不顯示「新增學校」
    final zhuyin = RegExp('[㄀-ㄯˊˇˋ˙]');
    final composing = zhuyin.hasMatch(_query);
    final q = norm(_query.replaceAll(zhuyin, '').trim());
    final matches = widget.schools.where((s) {
      final name = norm(s['name']?.toString() ?? '');
      final domains = (s['domains'] as List?)?.join(' ').toLowerCase() ?? '';
      return name.contains(q) || domains.contains(q);
    }).toList();
    final Widget results;
    if (q.isEmpty) {
      // 跟 TronClass 一樣，還沒打字不列出整份清單（六百多間太長），搜尋框已有提示
      results = const SizedBox.shrink();
    } else {
      results = ListView.separated(
        // 最後多一列「找不到學校？新增學校」
        itemCount: matches.length + (composing ? 0 : 1),
        separatorBuilder: (_, _) => Divider(height: 1, indent: 20, endIndent: 20, color: Colors.grey.shade200),
        itemBuilder: (_, i) {
          if (i == matches.length) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Icon(Icons.add, color: widget.accent),
              title: Text('找不到學校？新增學校',
                  style: TextStyle(color: widget.accent, fontWeight: FontWeight.bold)),
              // 回傳 add_new，登入頁接著問學校名稱
              onTap: () => Navigator.pop(context, {'add_new': true}),
            );
          }
          final s = matches[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text(s['name']?.toString() ?? '', style: const TextStyle(fontSize: 16)),
            subtitle: Text((s['domains'] as List?)?.join('、') ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () => Navigator.pop(context, s),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('學校', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '請填寫學校名稱',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              controller: _searchCtrl,
            ),
          ),
          Expanded(child: results),
        ],
      ),
    );
  }
}

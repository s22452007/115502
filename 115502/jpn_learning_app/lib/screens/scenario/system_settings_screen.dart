import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/providers/font_size_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';
import 'package:jpn_learning_app/screens/profile/change_password_screen.dart';
import 'package:jpn_learning_app/screens/profile/personal_info_screen.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF3E3E3E);
  static const Color borderColor = Color(0xFFE7E7E7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '系統設定',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  _buildMenuCard(
                    context: context,
                    icon: Icons.notifications_none_rounded,
                    iconColor: const Color(0xFFE0B128),
                    title: '通知提醒',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.verified_user_outlined,
                    iconColor: const Color(0xFF8DBA83),
                    title: '帳號與安全',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountSecurityScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.text_fields_rounded,
                    iconColor: const Color(0xFF6B9BD2),
                    title: '字體大小',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FontSizeSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.feedback_outlined,
                    iconColor: const Color(0xFFD28B6B),
                    title: '意見回饋',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0B0B0),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool dailyReminder = true;
  bool reviewReminder = true;
  bool streakReminder = true;
  bool friendNotification = false;

  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color textColor = Color(0xFF3E3E3E);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await NotificationService.loadSettings();
    if (!mounted) return;
    setState(() {
      dailyReminder = s['daily']!;
      reviewReminder = s['review']!;
      streakReminder = s['streak']!;
      friendNotification = s['friend']!;
    });
  }

  Future<void> _save() async {
    await NotificationService.saveSettings(
      daily: dailyReminder,
      review: reviewReminder,
      streak: streakReminder,
      friend: friendNotification,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '通知提醒',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildSwitchTile(
                  title: '每日學習提醒',
                  subtitle: '每天早上 8:00 提醒你開始學習',
                  value: dailyReminder,
                  onChanged: (value) {
                    setState(() => dailyReminder = value);
                    _save();
                  },
                ),
                _buildSwitchTile(
                  title: '單字複習提醒',
                  subtitle: '每天晚上 7:00 提醒你複習單字',
                  value: reviewReminder,
                  onChanged: (value) {
                    setState(() => reviewReminder = value);
                    _save();
                  },
                ),
                _buildSwitchTile(
                  title: '連續登入提醒',
                  subtitle: '每天晚上 9:00 提醒你維持連續紀錄',
                  value: streakReminder,
                  onChanged: (value) {
                    setState(() => streakReminder = value);
                    _save();
                  },
                ),
                _buildSwitchTile(
                  title: '好友互動通知',
                  subtitle: '例如好友新增、互動或排行榜變動',
                  value: friendNotification,
                  onChanged: (value) {
                    setState(() => friendNotification = value);
                    _save();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 12,
            ),
          ),
        ),
        value: value,
        activeColor: primaryGreen,
        onChanged: onChanged,
      ),
    );
  }
}

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color textColor = Color(0xFF3E3E3E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '帳號與安全',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final isGoogleOnly = user != null &&
                    user.providerData.isNotEmpty &&
                    user.providerData.every((p) => p.providerId == 'google.com');
                final showChangePassword = user != null && !isGoogleOnly;
                return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildActionTile(
                  icon: Icons.person_outline_rounded,
                  title: '個人資料',
                  subtitle: '查看與編輯你的基本資料',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalInfoScreen(),
                      ),
                    );
                  },
                ),
                if (showChangePassword)
                  _buildActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: '修改密碼',
                    subtitle: '更新帳號登入密碼',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                _buildActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: '刪除帳號',
                  subtitle: '永久刪除帳號與學習資料',
                  titleColor: Colors.redAccent,
                  onTap: () {
                    _showDeleteDialog(context);
                  },
                ),
              ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color titleColor = textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(icon, color: primaryGreen, size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB0B0B0),
          size: 26,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('刪除帳號'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '確定要刪除帳號嗎？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('刪除後以下資料將永久消失，無法復原：'),
              SizedBox(height: 8),
              Text('• 所有學習紀錄與能力值'),
              Text('• 收藏的單字與資料夾'),
              Text('• 成就徽章'),
              Text('• 好友關係與學習小組'),
              Text('• 個人資料與大頭貼'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // 二次確認
                _showFinalConfirmDialog(context);
              },
              child: const Text(
                '我要刪除',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFinalConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('最後確認'),
          content: const Text('此操作無法復原，確定要永久刪除帳號嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final userId = context.read<UserProvider>().userId;
                if (userId == null) return;

                final res = await ApiClient.deleteAccount(userId);

                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                } catch (_) {}

                if (!context.mounted) return;

                if (res['error'] != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'])),
                  );
                  return;
                }

                context.read<UserProvider>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('帳號已刪除，所有資料已清除')),
                );
              },
              child: const Text(
                '確認刪除',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 字體大小設定
// ==========================================
class FontSizeSettingsScreen extends StatelessWidget {
  const FontSizeSettingsScreen({super.key});

  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color textColor = Color(0xFF3E3E3E);

  @override
  Widget build(BuildContext context) {
    final fontProvider = context.watch<FontSizeProvider>();
    final scale = fontProvider.scale;

    String label;
    if (scale <= 0.9) {
      label = '小';
    } else if (scale <= 1.0) {
      label = '標準';
    } else if (scale <= 1.15) {
      label = '大';
    } else {
      label = '特大';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '字體大小',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7E7E7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '預覽效果',
                          style: TextStyle(
                            fontSize: 14 * scale,
                            color: const Color(0xFF8A8A8A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'こんにちは！日本語を勉強しましょう',
                          style: TextStyle(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '你好！一起來學日文吧',
                          style: TextStyle(
                            fontSize: 15 * scale,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14, color: textColor)),
                      Text('目前：$label', style: const TextStyle(fontSize: 14, color: textColor)),
                      const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  Slider(
                    value: scale,
                    min: 0.85,
                    max: 1.3,
                    divisions: 3,
                    activeColor: primaryGreen,
                    onChanged: (value) {
                      fontProvider.setScale(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        fontProvider.setScale(1.0);
                      },
                      child: const Text(
                        '恢復預設',
                        style: TextStyle(color: primaryGreen),
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
}

// ==========================================
// 意見回饋
// ==========================================
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color textColor = Color(0xFF3E3E3E);

  String _selectedType = '功能建議';
  final _contentController = TextEditingController();

  final _types = ['功能建議', 'Bug 回報', '使用體驗', '其他'];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入回饋內容')),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    final email = userProvider.email ?? '未登入';

    final subject = Uri.encodeComponent('[$_selectedType] JPN Learning App 意見回饋');
    final body = Uri.encodeComponent('回饋類型：$_selectedType\n使用者：$email\n\n$content');
    final uri = Uri.parse('mailto:your-team-email@gmail.com?subject=$subject&body=$body');

    try {
      await launchUrl(uri);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('感謝你的回饋！')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '意見回饋',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '回饋類型',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: _types.map((type) {
                      final isSelected = type == _selectedType;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: primaryGreen.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? primaryGreen : textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedType = type);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '回饋內容',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7E7E7)),
                    ),
                    child: TextField(
                      controller: _contentController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: '請描述你的建議或遇到的問題...',
                        hintStyle: TextStyle(color: Color(0xFFB0B0B0)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _sendFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '送出回饋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
}
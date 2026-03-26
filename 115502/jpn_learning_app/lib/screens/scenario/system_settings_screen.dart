import 'package:flutter/material.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  const SizedBox(height: 18),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: primaryGreen,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '系統設定',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
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
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 42,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0B0B0),
                size: 42,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '通知提醒',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSwitchTile(
            title: '每日學習提醒',
            subtitle: '每天固定時間提醒你開始學習',
            value: dailyReminder,
            onChanged: (value) {
              setState(() => dailyReminder = value);
            },
          ),
          _buildSwitchTile(
            title: '單字複習提醒',
            subtitle: '提醒你完成今天的單字複習',
            value: reviewReminder,
            onChanged: (value) {
              setState(() => reviewReminder = value);
            },
          ),
          _buildSwitchTile(
            title: '連續登入提醒',
            subtitle: '提醒你維持連續學習紀錄',
            value: streakReminder,
            onChanged: (value) {
              setState(() => streakReminder = value);
            },
          ),
          _buildSwitchTile(
            title: '好友互動通知',
            subtitle: '例如好友新增、互動或排行榜變動',
            value: friendNotification,
            onChanged: (value) {
              setState(() => friendNotification = value);
            },
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 13,
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '帳號與安全',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildActionTile(
            icon: Icons.person_outline_rounded,
            title: '個人資料',
            subtitle: '查看與編輯你的基本資料',
            onTap: () {},
          ),
          _buildActionTile(
            icon: Icons.lock_outline_rounded,
            title: '修改密碼',
            subtitle: '更新帳號登入密碼',
            onTap: () {},
          ),
          _buildActionTile(
            icon: Icons.link_rounded,
            title: '綁定 Google',
            subtitle: '將帳號與 Google 登入綁定',
            onTap: () {},
          ),
          _buildActionTile(
            icon: Icons.devices_other_rounded,
            title: '登出其他裝置',
            subtitle: '將其他裝置上的登入狀態移除',
            onTap: () {},
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: primaryGreen, size: 28),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 13,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB0B0B0),
          size: 30,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除帳號'),
          content: const Text('你確定要刪除帳號嗎？此操作無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 在這裡串接刪除帳號 API
              },
              child: const Text(
                '確認刪除',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
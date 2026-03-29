import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF3E3E3E);

  String? _displayName;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    _displayName = userProvider.username;
  }

  Future<void> _editNickname() async {
    final userId = context.read<UserProvider>().userId;
    final controller = TextEditingController(text: _displayName ?? '');
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('修改暱稱'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '中文或英文，2～20 字',
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = '請輸入暱稱');
                  return;
                }
                // 先呼叫後端檢查唯一性（排除自己）
                final myId = context.read<UserProvider>().userId;
                final check = await ApiClient.checkUsername(name, userId: myId);
                if (check['error'] != null) {
                  setDialogState(() => errorText = check['error']);
                  return;
                }
                if (check['available'] == false) {
                  setDialogState(() => errorText = '此暱稱已被使用');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, name);
              },
              child: const Text('確認', style: TextStyle(color: primaryGreen)),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;
    if (userId == null) return;

    final res = await ApiClient.updateUsername(userId, result);
    if (!mounted) return;

    if (res['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'])),
      );
      return;
    }

    await FirebaseAuth.instance.currentUser?.updateDisplayName(result);
    if (!mounted) return;
    context.read<UserProvider>().setUsername(result);
    setState(() => _displayName = result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暱稱已更新')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userProvider = context.watch<UserProvider>();

    final email = userProvider.email ?? firebaseUser?.email ?? '—';
    final rawName = email.contains('@') ? email.split('@')[0] : email;
    final displayName = _displayName?.isNotEmpty == true ? _displayName! : rawName;
    final japaneseLevel = userProvider.japaneseLevel.isNotEmpty
        ? userProvider.japaneseLevel
        : '尚未設定';
    final friendId = userProvider.friendId ?? '—';
    final avatar = userProvider.avatar;

    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB',
      '64B5F6', '4DD0E1', '4DB6AC', '81C784', 'AED581',
      'FFB74D', 'FF8A65',
    ];
    int hash = 0;
    for (int i = 0; i < displayName.length; i++) {
      hash = (hash * 31 + displayName.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final avatarBg = colors[hash % colors.length];
    final defaultAvatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=$avatarBg&color=fff';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '個人資料',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFC5E1A5),
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? (avatar.startsWith('http')
                            ? NetworkImage(avatar)
                            : MemoryImage(base64Decode(avatar)) as ImageProvider)
                        : NetworkImage(defaultAvatarUrl) as ImageProvider,
                  ),
                ),
                const SizedBox(height: 32),
                _buildEditableTile(
                  label: '暱稱',
                  value: displayName,
                  onTap: _editNickname,
                ),
                _buildInfoTile(label: 'Email', value: email),
                _buildInfoTile(label: '日文等級', value: japaneseLevel),
                _buildInfoTile(label: '好友 ID', value: friendId),
                _buildInfoTile(
                  label: '登入方式',
                  value: (firebaseUser?.providerData
                              .any((p) => p.providerId == 'google.com') ??
                          false)
                      ? 'Google 帳號'
                      : 'Email / 密碼',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 14),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF8A8A8A)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

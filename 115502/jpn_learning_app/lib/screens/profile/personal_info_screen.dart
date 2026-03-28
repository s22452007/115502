import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  static const Color bgColor = Color(0xFFF3F4EF);
  static const Color primaryGreen = Color(0xFF5C8663);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF3E3E3E);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userProvider = context.watch<UserProvider>();

    final email = userProvider.email ?? firebaseUser?.email ?? '—';
    final rawName = email.contains('@') ? email.split('@')[0] : email;
    final displayName = firebaseUser?.displayName ?? rawName;
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
                // 大頭貼
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFC5E1A5),
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? MemoryImage(base64Decode(avatar))
                        : NetworkImage(defaultAvatarUrl) as ImageProvider,
                  ),
                ),
                const SizedBox(height: 32),
                _buildInfoTile(label: '暱稱', value: displayName),
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
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 14,
            ),
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

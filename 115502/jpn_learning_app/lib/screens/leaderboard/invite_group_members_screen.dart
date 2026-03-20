import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class InviteGroupMembersScreen extends StatefulWidget {
  const InviteGroupMembersScreen({Key? key}) : super(key: key);

  @override
  State<InviteGroupMembersScreen> createState() =>
      _InviteGroupMembersScreenState();
}

class _InviteGroupMembersScreenState extends State<InviteGroupMembersScreen> {
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color beige = Color(0xFFF6EBC7);

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _friends = [
    {
      'name': '林美伶',
      'id': 'Lin Mei-Ling',
      'avatar': '',
      'invited': false,
      'joined': false,
    },
    {
      'name': '張宏豪',
      'id': 'Zhang-Hao',
      'avatar': '',
      'invited': false,
      'joined': false,
    },
    {
      'name': '陳玟柔',
      'id': 'Misan-Rou',
      'avatar': '',
      'invited': false,
      'joined': true,
    },
    {
      'name': '李威辰',
      'id': 'Li Wei-Chen',
      'avatar': '',
      'invited': false,
      'joined': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedCount =
        _friends.where((e) => e['invited'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '邀請好友加入小組',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.9),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已送出 $selectedCount 位好友邀請'),
                        ),
                      );
                    },
              child: Text(
                '邀請好友 $selectedCount 位',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋好友名稱或 ID',
                hintStyle: const TextStyle(color: Color(0x80333333)),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              itemCount: _filteredFriends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final friend = _filteredFriends[index];
                return _buildFriendCard(friend);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredFriends {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _friends;
    return _friends.where((friend) {
      final name = friend['name'].toString().toLowerCase();
      final id = friend['id'].toString().toLowerCase();
      return name.contains(keyword) || id.contains(keyword);
    }).toList();
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final bool invited = friend['invited'] == true;
    final bool joined = friend['joined'] == true;
    final String avatar = friend['avatar'] ?? '';
    final bool hasAvatar = avatar.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: beige),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryLighter,
            backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
            child: hasAvatar
                ? null
                : Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend['id'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: subText,
                  ),
                ),
              ],
            ),
          ),
          if (joined)
            _statusChip('已加入', lightGreen, AppColors.primary)
          else if (invited)
            _statusChip('等待回覆', const Color(0xFFEDEDED), subText)
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.9),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                setState(() {
                  friend['invited'] = true;
                });
              },
              child: const Text(
                '邀請',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
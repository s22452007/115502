import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'dart:convert'; // 用來解碼 Base64 圖片

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

  bool _isLoading = true;
  List<Map<String, dynamic>> _friends = []; // 存放從後端抓來的真實好友

  @override
  void initState() {
    super.initState();
    _fetchFriends(); // 畫面一開啟，就去抓真實好友名單
  }

  // 🌟 去後端抓取好友名單
  Future<void> _fetchFriends() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      final result = await ApiClient.getFriendsList(userId);
      
      if (mounted && result.containsKey('friends')) {
        setState(() {
          // 將後端資料轉換成我們要的格式，並預設 everyone invited = false
          _friends = (result['friends'] as List).map((f) {
            return {
              'name': f['nickname'] ?? 'Unknown',
              'id': f['friend_id'] ?? '',
              'avatar': f['avatar'] ?? '',
              'invited': false,
              'joined': false, // 在這個畫面，大家預設都是還沒加入的
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('抓取好友失敗: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 按下建立小組按鈕的動作
  Future<void> _submitCreateGroup(int selectedCount) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    // 找出所有被標記為 'invited' 的好友的專屬 ID
    final selectedFriendIds = _friends
        .where((f) => f['invited'] == true)
        .map((f) => f['id'].toString())
        .toList();

    // 顯示 Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在建立小組中...')),
    );

    // 呼叫建立小組 API
    final result = await ApiClient.createGroup(
      userId,
      '日文衝刺小組', // 你可以自訂群組名稱
      selectedFriendIds,
    );

    if (mounted) {
      if (result.containsKey('group_id')) {
        // 成功建立！關閉邀請畫面，退回到上層 (StudyGroupScreen 會自動偵測到新公會並跳入大廳)
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.pop(context); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '建立失敗，請重試')),
        );
      }
    }
  }

  // 將名字轉換為固定顏色 (當沒有大頭貼時使用)
  String _getFixedColor(String name) {
    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6',
      '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _friends.where((e) => e['invited'] == true).length;

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
                  : () => _submitCreateGroup(selectedCount), // 🌟 綁定送出動作
              child: Text(
                '確認建立小組 ($selectedCount 位)',
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(
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
          
          if (_friends.isEmpty)
            const Expanded(
              child: Center(
                child: Text('目前還沒有好友可以邀請喔！', style: TextStyle(color: subText, fontSize: 16)),
              ),
            )
          else
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
    final String avatarBase64 = friend['avatar'] ?? '';
    final String nickname = friend['name'];
    final String friendId = friend['id'];

    final String bgColor = _getFixedColor(nickname);
    final String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nickname)}&background=$bgColor&color=fff';

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
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (avatarBase64.isNotEmpty)
                ? MemoryImage(base64Decode(avatarBase64)) 
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$friendId',
                  style: const TextStyle(
                    fontSize: 14,
                    color: subText,
                  ),
                ),
              ],
            ),
          ),
          if (invited)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                setState(() {
                  friend['invited'] = false; // 取消邀請
                });
              },
              child: const Text(
                '已選取',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
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
                  // 控制最多只能邀請 4 個人 (加上自己剛好 5 個)
                  final currentSelected = _friends.where((e) => e['invited'] == true).length;
                  if (currentSelected < 4) {
                    friend['invited'] = true;
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('最多只能邀請 4 位好友喔！')),
                    );
                  }
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
}
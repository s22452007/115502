import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'dart:convert'; // 用來解碼 Base64 圖片

class InviteGroupMembersScreen extends StatefulWidget {
  // 核心關鍵：加入 groupId 參數。有傳值代表是「邀請加入現有群組」，沒傳代表是「建立新群組」
  final int? groupId; 

  const InviteGroupMembersScreen({Key? key, this.groupId}) : super(key: key);

  @override
  State<InviteGroupMembersScreen> createState() => _InviteGroupMembersScreenState();
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

  // 去後端抓取好友名單
  Future<void> _fetchFriends() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      // 智慧判斷抓取哪一種好友名單
      // 如果 groupId 為 null，是「建立群組模式」，抓一般好友清單
      // 如果 groupId 有值，是「邀請模式」，抓包含詳細狀態的好友清單
      final isCreating = widget.groupId == null;
      Map<String, dynamic> result;

      if (isCreating) {
        result = await ApiClient.getFriendsList(userId); // 原本的一般好友清單
      } else {
        // 呼叫剛剛新增的 API (詳細狀態)
        result = await ApiClient.getFriendsDetailedInvitationStatus(widget.groupId!, userId);
      }

      if (mounted && result.containsKey('friends')) {
        setState(() {
          // 將後端資料轉換成我們要的格式
          _friends = (result['friends'] as List).map((f) {
            // 如果是邀請模式，後端資料需要包含 'is_member' 和 'is_invited' 旗標
            // 如果是建立模式，後端沒有提供這些 flag，就預設為 false
            return {
              'name': f['nickname'] ?? 'Unknown',
              'id': f['friend_id'] ?? '',
              'avatar': f['avatar'] ?? '',
              'invited': false, // 這是 UI 上的勾選狀態，不是邀請狀態
              'is_member': f['is_member'] ?? false, // 🌟 核心旗標 1：是否已經是小組成員
              'is_invited': f['is_invited'] ?? false, // 🌟 核心旗標 2：是否已經發過邀請 (且狀態為 'pending')
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

  // 智慧判斷要「建立」還是「單純邀請」
  Future<void> _submitAction(int selectedCount) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final selectedFriendIds = _friends
        .where((f) => f['invited'] == true)
        .map((f) => f['id'].toString())
        .toList();

    // 根據模式顯示不同的提示文字
    final isCreating = widget.groupId == null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isCreating ? '正在建立小組中...' : '正在發送邀請...')),
    );

    Map<String, dynamic> result;

    if (isCreating) {
      // 模式 A：沒有小組，建立新小組
      result = await ApiClient.createGroup(userId, '日文衝刺小組', selectedFriendIds);
    } else {
      // 模式 B：已有小組，發送邀請到現有小組
      result = await ApiClient.inviteToExistingGroup(widget.groupId!, userId, selectedFriendIds);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      } else {
        // 成功！如果是純邀請，顯示後端真實回傳的 message
        if (!isCreating) {
          final successMessage = result['message'] ?? '邀請已順利送出！';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
        } else {
          // 如果是建立小組，也可以給個成功提示
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('小組建立成功！')));
        }
        Navigator.pop(context); 
      }
    }
  }

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
    final isCreating = widget.groupId == null; // 判斷是否為建立模式

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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: selectedCount == 0 ? null : () => _submitAction(selectedCount),
              child: Text(
                // 按鈕文字根據模式動態切換
                isCreating ? '確認建立小組 ($selectedCount 位)' : '發送邀請 ($selectedCount 位)',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_friends.isEmpty)
            const Expanded(child: Center(child: Text('目前還沒有好友可以邀請喔！', style: TextStyle(color: subText, fontSize: 16))))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                itemCount: _filteredFriends.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildFriendCard(_filteredFriends[index]),
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
    // 🌟 抓出狀態旗標
    final bool isMember = friend['is_member'] == true; 
    final bool isInvited = friend['is_invited'] == true; 
    final bool invitedUiSelected = friend['invited'] == true; // 這是 UI 上的勾選狀態

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
                Text(nickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark)),
                const SizedBox(height: 4),
                Text('@$friendId', style: const TextStyle(fontSize: 14, color: subText)),
              ],
            ),
          ),
          // 1. 如果已經是小組成員，顯示「已加入」並禁用
          if (isMember)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: null, // 禁用，不要讓他們操作
              child: const Text('已加入', style: TextStyle(color: subText, fontWeight: FontWeight.w700)),
            )
          // 2. 如果已經被邀請 (且狀態為 pending)，顯示「已邀請」並禁用 (🌟 解決你的問題)
          else if (isInvited)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen, // 使用淡綠色，不要用亮綠色
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: null, // 禁用，不要讓他們再次邀請
              child: const Text('已邀請', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            )
          // 3. 剩下情況：一般邀請或 UI 勾選
          else if (invitedUiSelected)
            ElevatedButton(
              onPressed: () => setState(() => friend['invited'] = false),
              child: const Text('已選取', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.9), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  // 控制最多只能邀請 4 個人 (加上自己剛好 5 個)
                  final currentSelected = _friends.where((e) => e['invited'] == true).length;
                  if (currentSelected < 4) {
                    friend['invited'] = true;
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最多只能邀請 4 位好友喔！')));
                  }
                });
              },
              child: const Text('邀請', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'dart:convert'; // 用來解碼 Base64 圖片
import 'study_group_screen.dart';

class InviteGroupMembersScreen extends StatefulWidget {
  // 核心關鍵：加入 groupId 參數。有傳值代表是「邀請加入現有群組」，沒傳代表是「建立新群組」
  final int? groupId; 

  // 用來接收從「設定小組」頁面傳來的資料
  final String? newGroupName;
  final String? goalType;
  final int? goalTarget;

  const InviteGroupMembersScreen({
    Key? key, 
    this.groupId,
    this.newGroupName, 
    this.goalType,     
    this.goalTarget,   
  }) : super(key: key);
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
      // 不管是不是建立模式，我們都呼叫「詳細狀態 API」
      final result = await ApiClient.getFriendsDetailedInvitationStatus(widget.groupId, userId);

      if (mounted) {
        setState(() {
          if (result.containsKey('friends')) {
            _friends = (result['friends'] as List).map((f) {
              return {
                'name': f['nickname']?.toString() ?? 'Unknown',
                'id': f['friend_id']?.toString() ?? '',
                'avatar': f['avatar']?.toString() ?? '',
                'invited': false,
                'has_group': f['has_group'] ?? false, // 🌟 接收是否已有小組
                'is_invited': f['is_invited'] ?? false, 
              };
            }).toList();
          } else if (result.containsKey('error')) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('抓取名單失敗：${result['error']}')));
          }
          _isLoading = false; 
        });
      }
    } catch (e) {
      print('抓取好友發生例外錯誤: $e');
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
      // 使用從上一頁傳來的真實資料，如果沒有就給預設值防呆
      final finalGroupName = widget.newGroupName ?? '日語學習小隊';
      final finalGoalType = widget.goalType ?? 'scans';
      final finalGoalTarget = widget.goalTarget ?? 30;

      result = await ApiClient.createGroup(
        userId, 
        finalGroupName, 
        selectedFriendIds,
        finalGoalType,     
        finalGoalTarget,  
      );
    } else {
      // 模式 B：已有小組，發送邀請到現有小組
      result = await ApiClient.inviteToExistingGroup(widget.groupId!, userId, selectedFriendIds);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      } else {
        // 🌟 成功狀態處理
        if (!isCreating) {
          // 情況 A：純邀請模式 ➡️ 單純退回上一頁 (大廳)
          final successMessage = result['message'] ?? '邀請已順利送出！';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
          Navigator.pop(context); 
        } else {
          // 情況 B：建立新小組模式 ➡️ 建立成功，跳轉到小組大廳！
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('小組建立成功！')));
          
          // 1. 先安全地退回最底層 (首頁)
          Navigator.of(context).popUntil((route) => route.isFirst);
          
          // 2. 稍微等 0.15 秒，讓退回動畫跑完，再順順地推入小組畫面
          Future.delayed(const Duration(milliseconds: 150), () {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyGroupScreen()),
              );
            }
          });
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
    // 狀態旗標
    final bool isMember = friend['is_member'] == true; 
    final bool isInvited = friend['is_invited'] == true; 
    final bool invitedUiSelected = friend['invited'] == true;

    final String avatarBase64 = friend['avatar']?.toString() ?? '';
    final String nickname = friend['name']?.toString() ?? 'Unknown';
    final String friendId = friend['id']?.toString() ?? '未知ID';

    // 產生大頭貼
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
          if (friend['has_group'] == true)
            // 1. 如果他已經在任何小組裡，顯示「已有小組」並禁用
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: null, // 禁用
              child: const Text('已有小組', style: TextStyle(color: subText, fontWeight: FontWeight.w700)),
            )
          else if (friend['is_invited'] == true)
            // 2. 如果已經被邀請過了，顯示「已邀請」並禁用
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: null, 
              child: const Text('已邀請', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            )
          else if (friend['invited'] == true)
            // 3. 正在打勾選取準備邀請的狀態
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => setState(() => friend['invited'] = false),
              child: const Text('已選取', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            )
          else
            // 4. 可以正常邀請的狀態
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.9), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
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
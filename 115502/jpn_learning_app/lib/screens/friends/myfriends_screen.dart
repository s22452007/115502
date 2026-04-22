import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart'; // 引入 API 工具
import 'package:jpn_learning_app/screens/friends/addfriends_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';

// 引入我們剛剛抽離出去的精美卡片積木
import 'package:jpn_learning_app/widgets/friends/friend_list_card.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({Key? key}) : super(key: key);

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final Color _darkGreen = const Color(0xFF4A7A4D);

  bool _isLoading = true;
  List<dynamic> _allFriends = []; 
  List<dynamic> _filteredFriends = []; 

  @override
  void initState() {
    super.initState();
    _fetchFriends(); // 畫面載入時去後端抓真實好友
  }

  // 去後端抓取真實好友清單
  Future<void> _fetchFriends() async {
    final userId = context.read<UserProvider>().userId;

    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await ApiClient.getFriendsList(userId);
      if (mounted) {
        setState(() {
          if (result.containsKey('friends') && result['friends'] is List) {
            _allFriends = result['friends'];
            _filteredFriends = _allFriends;
          } else {
            _allFriends = [];
            _filteredFriends = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _runFilter(String keyword) {
    if (keyword.isEmpty) {
      setState(() => _filteredFriends = _allFriends);
      return;
    }
    setState(() {
      _filteredFriends = _allFriends.where((friend) {
        if (friend is! Map) return false;
        final n = friend['nickname']?.toString() ?? '';
        final fId = friend['friend_id']?.toString() ?? '';
        return n.toLowerCase().contains(keyword.toLowerCase()) ||
            fId.toLowerCase().contains(keyword.toLowerCase());
      }).toList();
    });
  }

  // ==========================================
  // 彈窗與設定邏輯區域
  // ==========================================

  // 1. 顯示底部動作選單 (Action Sheet)
  void _showFriendActionSheet(dynamic friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 透明背景以顯示圓角懸浮
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上方白色區塊
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ListTile(
                      title: const Center(child: Text('設定暱稱', style: TextStyle(fontSize: 18, color: Colors.black87))),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditNicknameDialog(friend);
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFEAEAEA)),
                    ListTile(
                      title: const Center(child: Text('刪除好友', style: TextStyle(fontSize: 18, color: Colors.red))),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showDeleteFriendDialog(friend);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 下方白色區塊 (取消按鈕)
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: const Center(child: Text('取消', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. 設定暱稱的對話框
  void _showEditNicknameDialog(dynamic friend) {
    final friendId = friend['friend_id']?.toString() ?? '';
    final oldNickname = friend['nickname']?.toString() ?? '';
    final controller = TextEditingController(text: oldNickname);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('設定暱稱', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkGreen),
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isEmpty) return;
              Navigator.pop(ctx); 
              
              final userId = context.read<UserProvider>().userId;
              if (userId != null) {
                final res = await ApiClient.updateFriendNickname(userId, friendId, newNickname);
                if (mounted) {
                  if (res['error'] != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暱稱已更新！')));
                    _fetchFriends(); 
                  }
                }
              }
            },
            child: const Text('儲存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 3. 刪除好友的確認對話框
  void _showDeleteFriendDialog(dynamic friend) {
    final nickname = friend['nickname']?.toString() ?? 'Unknown';
    final friendId = friend['friend_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('刪除好友', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('確定要刪除好友「$nickname」嗎？\n刪除後將無法恢復。', style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); 
              
              final userId = context.read<UserProvider>().userId;
              if (userId != null) {
                final res = await ApiClient.deleteFriend(userId, friendId);
                if (mounted) {
                  if (res['error'] != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除好友')));
                    _fetchFriends(); 
                  }
                }
              }
            },
            child: const Text('確定刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI 畫面建構
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('我的好友', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.groups_outlined, color: _darkGreen, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupScreen())),
          ),
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: _darkGreen, size: 28),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddFriendScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _darkGreen))
          : _allFriends.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _filteredFriends.isEmpty
                      ? Center(child: Text('找不到符合的好友 🥲', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            // 使用我們新建立的卡片積木
                            return FriendListCard(
                              friend: _filteredFriends[index],
                              onMoreTap: () => _showFriendActionSheet(_filteredFriends[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          onChanged: (value) => _runFilter(value),
          decoration: InputDecoration(
            hintText: '搜尋好友暱稱或 ID',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('目前還沒有好友喔！', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddFriendScreen())),
            icon: const Icon(Icons.person_add_outlined, color: Colors.white),
            label: const Text('去新增好友', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
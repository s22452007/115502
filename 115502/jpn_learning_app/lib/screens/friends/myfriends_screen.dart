import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart'; // 引入 API 工具
import 'package:jpn_learning_app/screens/friends/addfriends_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({Key? key}) : super(key: key);

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final Color _lightGreen = const Color(0xFFBFE1C3);

  bool _isLoading = true;
  List<dynamic> _allFriends = [];      // 存放從資料庫抓來的所有好友
  List<dynamic> _filteredFriends = []; // 存放搜尋列過濾後的好友

  @override
  void initState() {
    super.initState();
    _fetchFriends(); // 畫面載入時去後端抓真實好友
  }

  // 去後端抓取真實好友清單的魔法
  Future<void> _fetchFriends() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final result = await ApiClient.getFriendsList(userId);
    
    if (mounted) {
      setState(() {
        if (result.containsKey('friends')) {
          _allFriends = result['friends'];
          _filteredFriends = _allFriends; // 一開始顯示全部
        }
        _isLoading = false;
      });
    }
  }

  // 本地即時搜尋過濾邏輯
  void _runFilter(String keyword) {
    List<dynamic> results = [];
    if (keyword.isEmpty) {
      results = _allFriends;
    } else {
      results = _allFriends.where((friend) =>
          friend['nickname'].toString().toLowerCase().contains(keyword.toLowerCase()) ||
          friend['friend_id'].toString().toLowerCase().contains(keyword.toLowerCase())
      ).toList();
    }
    setState(() {
      _filteredFriends = results;
    });
  }

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
        title: const Text(
          '我的好友',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 你的捷徑保留！
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: _darkGreen, size: 28),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 根據狀態切換畫面：載入中 -> 空狀態 -> 有資料的列表
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _darkGreen))
          : _allFriends.isEmpty
              ? _buildEmptyState() // 完全保留你的溫馨空畫面
              : Column(
                  children: [
                    // --- 頂部搜尋列 ---
                    _buildSearchBar(),
                    
                    // --- 好友列表 ---
                    Expanded(
                      child: _filteredFriends.isEmpty
                          ? Center(child: Text('找不到符合的好友 🥲', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _filteredFriends.length,
                              itemBuilder: (context, index) {
                                return _buildFriendCard(_filteredFriends[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  // 🔍 搜尋列模具 (為了配合你的 UI 新增的)
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: TextField(
          onChanged: (value) => _runFilter(value), // 打字時即時搜尋
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

  // 🃏 單個好友的質感卡片模具 (接收真實的 dynamic 資料)
  Widget _buildFriendCard(dynamic friend) {
    final nickname = friend['nickname'] ?? 'Unknown';
    final friendId = friend['friend_id'] ?? '';
    final avatarBase64 = friend['avatar'];
    
    // 因為資料庫目前沒有 status 欄位，我們先統一給一句溫馨的話，不破壞你的 UI
    final statusText = '一起開心學日文 📚'; 

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // 1. 頭像 (動態判斷：如果沒有上傳大頭貼就給隨機圖)
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatarBase64 != null 
                ? null // TODO: 未來接 Base64 解析
                : const NetworkImage('https://ui-avatars.com/api/?name=F&background=random'),
          ),
          const SizedBox(width: 16),
          // 2. 中間的好友資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$friendId',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _lightGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: _darkGreen, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // 3. 右側按鈕 
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black54),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('準備與 $nickname 聊天！')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🏜️ 沒好友的時候顯示的溫馨空狀態 (100% 完全保留你的設計)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '目前還沒有好友喔！',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
              );
            },
            icon: const Icon(Icons.person_add_outlined, color: Colors.white),
            label: const Text(
              '去新增好友',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
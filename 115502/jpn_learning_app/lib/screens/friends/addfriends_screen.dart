import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 控制手機剪貼簿
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart'; // 🌟 你的捷徑頁面
import 'package:jpn_learning_app/utils/api_client.dart'; // 🌟 引入 API 工具

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({Key? key}) : super(key: key);

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  // 沿用你的質感深綠色
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final Color _lightGreen = const Color(0xFFBFE1C3);

  // 模擬按鈕狀態
  bool _isRequestSent = false;

  // 搜尋功能專用的狀態變數
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _foundUser; 
  bool _isFoundUserRequestSent = false; 

  // 執行搜尋的魔法函數
  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    // 抓取自己的 ID，防止搜尋自己
    final myFriendId = context.read<UserProvider>().friendId;
    if (keyword == myFriendId) {
      setState(() {
        _foundUser = null;
        _searchError = '不能搜尋自己喔！😆';
      });
      return;
    }

    // 隱藏鍵盤並顯示載入中
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundUser = null;
      _isFoundUserRequestSent = false;
    });

    // 呼叫 API
    final result = await ApiClient.searchFriend(keyword);

    // 更新畫面
    if (mounted) {
      setState(() {
        _isSearching = false;
        if (result.containsKey('error')) {
          _searchError = result['error'];
        } else {
          _foundUser = result;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 從大腦中取出自己的專屬 ID
    final myFriendId = context.watch<UserProvider>().friendId ?? '尚未產生';

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
          '新增好友',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 🌟 保留你寫的右上角捷徑：直接跳去好友列表！
          IconButton(
            icon: Icon(Icons.people_outline, color: _darkGreen, size: 28),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. 搜尋列 ---
              _buildSearchBar(),
              const SizedBox(height: 16),

              // --- 動態搜尋結果區塊 ---
              if (_isSearching)
                Center(child: CircularProgressIndicator(color: _darkGreen))
              else if (_searchError != null)
                Center(
                  child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                )
              else if (_foundUser != null)
                _buildFoundUserCard(), // 顯示找到的人

              const SizedBox(height: 24),

              // --- 2. 我的專屬 ID 卡片 ---
              _buildMyIdCard(myFriendId),
              const SizedBox(height: 32),

              // --- 3. 好友邀請 (待確認) ---
              const Text(
                '好友邀請',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              _buildPendingRequestCard(
                '田中先生',
                'tanaka_san',
                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80',
              ),

              const SizedBox(height: 32),

              // --- 4. 推薦學習夥伴 ---
              const Text(
                '推薦學習夥伴',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              _buildSuggestedFriendCard(
                '佐藤學長',
                'sato_senpai',
                'https://images.unsplash.com/photo-1527980965255-d3b416303d12?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80',
              ),
              _buildSuggestedFriendCard(
                '鈴木同學',
                'suzuki_123',
                'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔍 搜尋列模具
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search, // 鍵盤右下角變成「搜尋」按鈕
        onSubmitted: (_) => _performSearch(), // 按下鍵盤搜尋時觸發
        decoration: InputDecoration(
          hintText: '輸入用戶專屬 ID 搜尋',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: IconButton(
            icon: const Icon(Icons.search, color: Colors.grey),
            onPressed: _performSearch, // 點擊放大鏡也能搜尋
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF4A7A4D)),
            onPressed: () {
              // TODO: 未來接掃描 QR Code 功能
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // 🌟 顯示搜尋到的用戶卡片
  Widget _buildFoundUserCard() {
    final email = _foundUser!['email'] as String;
    final nickname = email.split('@')[0];
    final targetId = _foundUser!['friend_id'];
    final avatarBase64 = _foundUser!['avatar'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _lightGreen.withOpacity(0.1), // 給搜尋結果一個微微的綠色底
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _darkGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24, 
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatarBase64 != null 
                ? null // TODO: 未來接上 Base64 解碼
                : const NetworkImage('https://ui-avatars.com/api/?name=User&background=random'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '@$targetId', 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isFoundUserRequestSent = !_isFoundUserRequestSent;
              });
              if (_isFoundUserRequestSent) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好友邀請已送出！')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFoundUserRequestSent ? Colors.grey.shade200 : _darkGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              _isFoundUserRequestSent ? '已送出' : '加好友',
              style: TextStyle(
                color: _isFoundUserRequestSent ? Colors.grey.shade600 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 💳 我的 ID 卡片模具
  Widget _buildMyIdCard(String myId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGreen),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的專屬 ID', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                myId,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: _darkGreen),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.black54),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: myId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID 已複製到剪貼簿！📋'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
              ),
              IconButton(icon: Icon(Icons.qr_code, color: _darkGreen), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  // 📩 待確認的好友邀請模具
  Widget _buildPendingRequestCard(String name, String id, String avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('@$id', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () {}),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: _darkGreen, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.check, color: Colors.white), onPressed: () {}),
          ),
        ],
      ),
    );
  }

  // 🤝 推薦好友模具
  Widget _buildSuggestedFriendCard(String name, String id, String avatarUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('@$id', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isRequestSent = !_isRequestSent;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRequestSent ? Colors.grey.shade200 : _lightGreen.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              _isRequestSent ? '已送出' : '加好友',
              style: TextStyle(color: _isRequestSent ? Colors.grey.shade600 : _darkGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
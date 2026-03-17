import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 控制手機剪貼簿
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart'; 
import 'package:jpn_learning_app/utils/api_client.dart'; 

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({Key? key}) : super(key: key);

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final Color _lightGreen = const Color(0xFFBFE1C3);

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _foundUser; 
  bool _isFoundUserRequestSent = false; 

  // 存放從後端抓來的「待確認邀請」
  List<dynamic> _pendingRequests = [];
  bool _isLoadingPending = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests(); // 畫面載入時去抓取邀請
  }

  // 去後端抓取「誰寄邀請給我」
  Future<void> _fetchPendingRequests() async {
    final myUserId = context.read<UserProvider>().userId;
    if (myUserId == null) return;

    final result = await ApiClient.getPendingRequests(myUserId);
    if (mounted) {
      setState(() {
        if (result.containsKey('pending_requests')) {
          _pendingRequests = result['pending_requests'];
        }
        _isLoadingPending = false;
      });
    }
  }

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
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FriendsListScreen()));
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
                Center(child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
              else if (_foundUser != null)
                _buildFoundUserCard(),

              const SizedBox(height: 24),
              _buildMyIdCard(myFriendId),
              const SizedBox(height: 32),

              // --- 🌟 動態顯示待確認的好友邀請 ---
              const Text('好友邀請', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              
              if (_isLoadingPending)
                const Center(child: CircularProgressIndicator())
              else if (_pendingRequests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Text('目前沒有新的好友邀請喔！', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              else
                ..._pendingRequests.map((req) => _buildPendingRequestCard(req)).toList(),

              const SizedBox(height: 32),

              // 推薦學習夥伴 (保持靜態示範)
              const Text('推薦學習夥伴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              _buildSuggestedFriendCard('佐藤學長', 'sato_senpai', 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search, // 鍵盤右下角變成「搜尋」按鈕
        onSubmitted: (_) => _performSearch(), // 按下鍵盤搜尋時觸發
        decoration: InputDecoration(
          hintText: '輸入用戶專屬 ID 搜尋',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.grey), onPressed: _performSearch),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // 🌟 真實搜尋到的用戶卡片
  Widget _buildFoundUserCard() {
    final email = _foundUser!['email'] as String;
    final nickname = email.split('@')[0];
    final targetId = _foundUser!['friend_id'];
    final targetUserId = _foundUser!['user_id'];
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
            backgroundImage: avatarBase64 != null ? null : const NetworkImage('https://ui-avatars.com/api/?name=User&background=random'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('@$targetId', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isFoundUserRequestSent ? null : () async {
              // 🌟 發送邀請到後端
              final myUserId = context.read<UserProvider>().userId;
              if (myUserId == null) return;

              final response = await ApiClient.sendFriendRequest(myUserId, targetUserId);
              
              if (response.containsKey('error')) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['error'])));
              } else {
                setState(() => _isFoundUserRequestSent = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好友邀請已順利送出！')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFoundUserRequestSent ? Colors.grey.shade300 : _darkGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              _isFoundUserRequestSent ? '已送出' : '加好友',
              style: TextStyle(color: _isFoundUserRequestSent ? Colors.grey.shade600 : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyIdCard(String myId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _lightGreen.withOpacity(0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: _lightGreen)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的專屬 ID', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(myId, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: _darkGreen)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.black54),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: myId));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID 已複製到剪貼簿！📋'), behavior: SnackBarBehavior.floating));
                },
              ),
              IconButton(icon: Icon(Icons.qr_code, color: _darkGreen), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  // 🌟 動態待確認的好友邀請模具
  Widget _buildPendingRequestCard(Map<String, dynamic> req) {
    final requestId = req['request_id'];
    final nickname = req['nickname'];
    final friendId = req['friend_id'];
    final avatarBase64 = req['avatar'];

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
          CircleAvatar(
            radius: 24, 
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatarBase64 != null ? null : const NetworkImage('https://ui-avatars.com/api/?name=User&background=random'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('@$friendId', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          // 拒絕按鈕
          Container(
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey), 
              onPressed: () async {
                await ApiClient.respondFriendRequest(requestId, 'reject');
                _fetchPendingRequests(); // 拒絕後重新整理畫面
              }
            ),
          ),
          const SizedBox(width: 8),
          // 接受按鈕
          Container(
            decoration: BoxDecoration(color: _darkGreen, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.white), 
              onPressed: () async {
                await ApiClient.respondFriendRequest(requestId, 'accept');
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已和 $nickname 成為好友！🎉')));
                _fetchPendingRequests(); // 接受後重新整理畫面
              }
            ),
          ),
        ],
      ),
    );
  }

  // 🤝 推薦好友模具 (靜態示範用)
  Widget _buildSuggestedFriendCard(String name, String id, String avatarUrl) {
    bool isSent = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
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
                onPressed: () => setCardState(() => isSent = !isSent),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSent ? Colors.grey.shade200 : _lightGreen.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(isSent ? '已送出' : '加好友', style: TextStyle(color: isSent ? Colors.grey.shade600 : _darkGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart'; 
import 'package:jpn_learning_app/utils/api_client.dart'; 

import 'package:jpn_learning_app/widgets/friends/found_user_card.dart';
import 'package:jpn_learning_app/widgets/friends/pending_request_card.dart';
import 'package:jpn_learning_app/widgets/friends/my_id_card.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({Key? key}) : super(key: key);

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _foundUser; 
  bool _isFoundUserRequestSent = false; 

  List<dynamic> _pendingRequests = [];
  bool _isLoadingPending = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    final myUserId = context.read<UserProvider>().userId;
    if (myUserId == null) {
      if (mounted) setState(() => _isLoadingPending = false);
      return;
    }
    try {
      final result = await ApiClient.getPendingRequests(myUserId);
      if (mounted) {
        setState(() {
          if (result.containsKey('pending_requests')) _pendingRequests = result['pending_requests'];
          _isLoadingPending = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final myFriendId = context.read<UserProvider>().friendId;
    if (keyword == myFriendId) {
      setState(() { _foundUser = null; _searchError = '不能搜尋自己喔！😆'; });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isSearching = true; _searchError = null; _foundUser = null; _isFoundUserRequestSent = false; });

    final result = await ApiClient.searchFriend(keyword);

    if (mounted) {
      setState(() {
        _isSearching = false;
        if (result.containsKey('error')) _searchError = result['error'];
        else _foundUser = result;
      });
    }
  }

  Future<void> _sendFriendRequest(int targetUserId) async {
    final myUserId = context.read<UserProvider>().userId;
    if (myUserId == null) return;

    final response = await ApiClient.sendFriendRequest(myUserId, targetUserId);
    if (mounted) {
      if (response.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['error'])));
      } else {
        setState(() => _isFoundUserRequestSent = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好友邀請已順利送出！')));
      }
    }
  }

  Future<void> _respondToRequest(int requestId, String action, String nickname) async {
    await ApiClient.respondFriendRequest(requestId, action);
    if (mounted && action == 'accept') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已和 $nickname 成為好友！🎉')));
    }
    _fetchPendingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myFriendId = context.watch<UserProvider>().friendId ?? '尚未產生';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('新增好友', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.people_outline, color: _darkGreen, size: 28),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FriendsListScreen())),
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
              _buildSearchBar(),
              const SizedBox(height: 16),

              if (_isSearching)
                Center(child: CircularProgressIndicator(color: _darkGreen))
              else if (_searchError != null)
                Center(child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
              else if (_foundUser != null)
                FoundUserCard(
                  user: _foundUser!,
                  isRequestSent: _isFoundUserRequestSent,
                  onSendRequest: () => _sendFriendRequest(_foundUser!['user_id'] as int), // ✅ 確保傳遞的是整數
                ),

              const SizedBox(height: 24),
              MyIdCard(myId: myFriendId),
              const SizedBox(height: 32),

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
                ..._pendingRequests.map((req) => PendingRequestCard(
                  request: req,
                  onAccept: () => _respondToRequest(req['request_id'], 'accept', req['nickname'] ?? 'User'),
                  onReject: () => _respondToRequest(req['request_id'], 'reject', ''),
                )).toList(),

              const SizedBox(height: 32),
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
        textInputAction: TextInputAction.search, 
        onSubmitted: (_) => _performSearch(), 
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
}
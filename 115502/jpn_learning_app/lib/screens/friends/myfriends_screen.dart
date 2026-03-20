import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart'; // 引入 API 工具
import 'package:jpn_learning_app/screens/friends/addfriends_screen.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';
import 'dart:convert';
import 'package:jpn_learning_app/screens/friends/chat_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({Key? key}) : super(key: key);

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final Color _lightGreen = const Color(0xFFBFE1C3);

  bool _isLoading = true;
  List<dynamic> _allFriends = []; // 存放從資料庫抓來的所有好友
  List<dynamic> _filteredFriends = []; // 存放搜尋列過濾後的好友

  // 存放被加入「學習小組」的好友名單
  final List<Map<String, String>> _groupMembers = [];

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
            print('⚠️ 警告：後端傳來的 friends 不是 List 格式或沒有資料！');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('抓取好友發生錯誤: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 本地即時搜尋過濾邏輯
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
          // 前往學習小組的按鈕 (帶著我們選好的名單過去)
          IconButton(
            icon: Icon(Icons.groups, color: _darkGreen, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudyGroupScreen(members: _groupMembers),
                ),
              );
            },
          ),
          // 新增好友按鈕
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _darkGreen))
          : _allFriends.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _filteredFriends.isEmpty
                      ? Center(
                          child: Text(
                            '找不到符合的好友 🥲',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        )
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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

  // 將名字轉換為「永遠固定」的專屬顏色代碼
  String _getFixedColor(String name) {
    final List<String> colors = [
      'E57373', 'F06292', 'BA68C8', '9575CD', '7986CB', '64B5F6',
      '4DD0E1', '4DB6AC', '81C784', 'AED581', 'FFB74D', 'FF8A65'
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF; // 保證每次算出來數字一樣
    }
    return colors[hash % colors.length];
  }

  // 卡片模具
  Widget _buildFriendCard(dynamic friend) {
    if (friend == null || friend is! Map) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        color: Colors.red.shade100,
        child: Text(
          '❌ 資料格式錯誤: $friend',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final nickname = friend['nickname']?.toString() ?? 'Unknown';
    final friendId = friend['friend_id']?.toString() ?? '尚未產生';
    final String? avatarBase64 = friend['avatar']?.toString();

    // 判斷這個好友是否已經被我們加進小組名單裡了
    bool isAdded = _groupMembers.any((m) => m['friend_id'] == friendId);

    final statusText = '一起開心學日文 📚';

    // 取得專屬固定顏色
    final String bgColor = _getFixedColor(nickname);
    // 把網址裡的 random 換成算出來的 $bgColor
    final String defaultAvatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nickname)}&background=$bgColor&color=fff';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 替換這裡的 CircleAvatar
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade200,
            // 如果後端有傳真實 Base64 圖片，就顯示真實圖片；否則顯示專屬預設圖
            backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                ? MemoryImage(base64Decode(avatarBase64)) 
                : NetworkImage(defaultAvatarUrl) as ImageProvider,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$friendId',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _lightGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: _darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 右側的按鈕區 ---
          Row(
            children: [
              // 聊天按鈕
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.black54,
                    size: 20,
                  ),
                  onPressed: () {
                    // 換成跳轉到真實的聊天畫面！
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          friendName: nickname, // 把這個朋友的名字傳過去
                          // 如果他有真實頭像或是我們算出來的預設頭像，也傳過去
                          friendAvatarUrl: (avatarBase64 != null && avatarBase64.isNotEmpty) 
                              ? null // 如果是 Base64 比較複雜，我們這邊先簡單處理，如果需要可以再改
                              : defaultAvatarUrl, 
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 加入小組按鈕
              Container(
                decoration: BoxDecoration(
                  color: isAdded ? Colors.red.shade50 : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isAdded ? Icons.group_remove : Icons.group_add,
                    color: isAdded ? Colors.red.shade400 : _darkGreen,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isAdded) {
                        // 移出小組
                        _groupMembers.removeWhere(
                          (m) => m['friend_id'] == friendId,
                        );
                      } else {
                        // 加入小組 (最多5人)
                        if (_groupMembers.length < 5) {
                          _groupMembers.add({
                            'nickname': nickname,
                            'friend_id': friendId,
                            'avatar': (avatarBase64 != null && avatarBase64.isNotEmpty) 
                                ? avatarBase64 
                                : defaultAvatarUrl,
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('小組最多只能有5個人喔！')),
                          );
                        }
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
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
              Navigator.pushReplacement(
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

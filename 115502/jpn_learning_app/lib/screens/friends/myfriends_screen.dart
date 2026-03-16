import 'package:flutter/material.dart';
// 🌟 匯入我們剛剛做好的新增好友頁面
import 'package:jpn_learning_app/screens/friends/addfriends_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({Key? key}) : super(key: key);

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  // 沿用你的質感深綠色與淺綠色
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final Color _lightGreen = const Color(0xFFBFE1C3);

  // 🌟 假資料：你的好友列表 (未來可以換成從資料庫抓取)
  final List<Map<String, String>> _friends = [
    {
      'name': '山田太郎',
      'id': 'yamada_99',
      'avatar':
          'https://images.unsplash.com/photo-1599566150163-29194dcaad36?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80',
      'status': '正在學習 N3 📚',
    },
    {
      'name': '陳小明',
      'id': 'ming_chen',
      'avatar':
          'https://images.unsplash.com/photo-1527980965255-d3b416303d12?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80',
      'status': '剛完成 50 音 ✨',
    },
    {
      'name': 'Emily',
      'id': 'emily_jp',
      'avatar':
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.0.3&auto=format&fit=crop&w=100&q=80',
      'status': '熱愛日本文化 🌸',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淡淡的灰白色背景
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
          // 🌟 右上角的捷徑：直接跳去好友列表！
          IconButton(
            icon: Icon(Icons.people_outline, color: _darkGreen, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 如果還沒有好友，顯示空狀態；有的話就顯示列表
      body: _friends.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return _buildFriendCard(friend);
              },
            ),
    );
  }

  // 🃏 單個好友的質感卡片模具
  Widget _buildFriendCard(Map<String, String> friend) {
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
          // 1. 頭像
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(friend['avatar']!),
          ),
          const SizedBox(width: 16),
          // 2. 中間的好友資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${friend['id']!}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                // 標籤樣式的學習狀態
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
                    friend['status']!,
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
          // 3. 右側按鈕 (打招呼/聊天)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.black54,
              ),
              onPressed: () {
                // TODO: 未來這裡可以接上聊天室系統
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🏜️ 沒好友的時候顯示的溫馨空狀態
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

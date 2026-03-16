import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/friends/myfriends_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淡淡的灰白色背景，讓白卡片更立體
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

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. 搜尋列 ---
              _buildSearchBar(),
              const SizedBox(height: 24),

              // --- 2. 我的專屬 ID 卡片 ---
              _buildMyIdCard(),
              const SizedBox(height: 32),

              // --- 3. 好友邀請 (待確認) ---
              const Text(
                '好友邀請',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: '輸入用戶 ID 或暱稱搜尋',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
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

  // 💳 我的 ID 卡片模具
  Widget _buildMyIdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightGreen.withOpacity(0.3), // 淡綠色底
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGreen),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '我的專屬 ID',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                'JPN-9527',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.black54),
                onPressed: () {
                  // TODO: 接複製到剪貼簿功能
                },
              ),
              IconButton(
                icon: Icon(Icons.qr_code, color: _darkGreen),
                onPressed: () {
                  // TODO: 顯示我的 QR Code
                },
              ),
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
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '@$id',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          // 拒絕按鈕
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 8),
          // 接受按鈕
          Container(
            decoration: BoxDecoration(
              color: _darkGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: () {},
            ),
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
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '@$id',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          // 加好友按鈕 (點擊會有狀態變化)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isRequestSent = !_isRequestSent;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRequestSent
                  ? Colors.grey.shade200
                  : _lightGreen.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              _isRequestSent ? '已送出' : '加好友',
              style: TextStyle(
                color: _isRequestSent ? Colors.grey.shade600 : _darkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

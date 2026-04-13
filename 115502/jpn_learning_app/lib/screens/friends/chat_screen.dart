import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart'; // 確保這裡有引入你的 AppColors

class ChatScreen extends StatefulWidget {
  final String friendName;
  final String? friendAvatarUrl;

  const ChatScreen({Key? key, required this.friendName, this.friendAvatarUrl})
    : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  // 模擬的聊天紀錄 (實戰中會從 Firebase 或你的後端資料庫抓取)
  final List<Map<String, dynamic>> _messages = [
    {'type': 'system', 'text': '今天'},
    {'type': 'text', 'isMe': false, 'text': '你最近進度很快耶！', 'time': '10:00 AM'},
    {
      'type': 'text',
      'isMe': true,
      'text': '對啊！我每天都有堅持拍照解鎖單字 📸',
      'time': '10:05 AM',
    },
    {
      'type': 'system', // 系統提示訊息
      'text': 'Din 獲得了「麵食大師」徽章 🏅',
    },
    {'type': 'text', 'isMe': false, 'text': '太神啦！我要追上你了', 'time': '10:12 AM'},
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'type': 'text',
        'isMe': true,
        'text': text,
        'time': 'Just now',
      });
    });

    _messageController.clear();
    // TODO: 這裡之後可以加入把訊息發送給後端 API 的邏輯
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 聊天訊息列表
          Expanded(
            child: ListView.builder(
              itemBuilder: (context, index) {
                final msg = _messages[index];

                // 防呆機制：確保就算是 null 也能當作 false 處理
                bool isUserMessage = msg['isUser'] ?? false;

                if (msg['type'] == 'system') {
                  return _buildSystemMessage(msg['text']);
                } else if (isUserMessage) {
                  // 👈 換成檢查 isUserMessage！
                  return _buildMyMessage(msg['text']);
                } else {
                  return _buildFriendMessage(msg['text']);
                }
              },
            ),
          ),
          // 底部輸入框
          _buildMessageInput(),
        ],
      ),
    );
  }

  // --- 頂部導覽列 ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '@${widget.friendName}',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.black87),
          onPressed: () {
            // TODO: 開啟好友設定選單
          },
        ),
      ],
    );
  }

  // --- 系統訊息框 (例如：今天、獲得徽章) ---
  Widget _buildSystemMessage(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- 朋友發的訊息 (靠左，有頭像) ---
  Widget _buildFriendMessage(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 朋友頭像
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: widget.friendAvatarUrl != null
                ? NetworkImage(widget.friendAvatarUrl!)
                : null,
            child: widget.friendAvatarUrl == null
                ? Text(
                    widget.friendName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.black54),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // 訊息泡泡
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          // 留白避免太靠右
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- 自己發的訊息 (靠右，綠色) ---
  Widget _buildMyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 留白避免太靠左
          const SizedBox(width: 48),
          // 訊息泡泡
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF6AA86B), // 你的 AppColors.primary
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 底部輸入框 ---
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 附加檔案按鈕
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.black54),
                onPressed: () {
                  // TODO: 開啟相簿或相機
                },
              ),
            ),
            const SizedBox(width: 12),
            // 文字輸入框
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: '輸入訊息...',
                    hintStyle: TextStyle(color: Colors.black38),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 發送按鈕
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF6AA86B), // 你的 AppColors.primary
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

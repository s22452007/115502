import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/naturalness_screen.dart';

// 2-2-4 角色扮演
class RoleplayScreen extends StatefulWidget {
  // 🌟 1. 新增一個「變數口袋」，準備用來裝上一頁傳來的標題名稱
  final String topicTitle;

  // 🌟 2. 規定進來這個頁面（聊天室）時，一定要附帶傳入這個標題
  const RoleplayScreen({Key? key, required this.topicTitle}) : super(key: key);
  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // 讓第一句話變成動態的，把選到的主題塞進去！
    _messages.add({
      'text': '歡迎來到「${widget.topicTitle}」的情境！我是你的 AI 日語小幫手，請試著用日文開個頭吧！😊',
      'isUser': false,
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return; // 沒打字不理他

    setState(() {
      // 1. 把你打的字，變成綠色氣泡加進對話裡
      _messages.add({'text': text, 'isUser': true});
    });

    // 2. 清空輸入框
    _controller.clear();
    // 3. 替換：向你的 Python 後端發送真正的請求
    try {
      // 這邊的網址請換成你 Python 後端真正運行的網址（例如 http://127.0.0.1:8000/chat）
      final url = Uri.parse('http://你的後端API網址/路徑'); 
      
      // 發送請求，把你剛剛打的字 (text) 傳給後端
      final response = await http.post(
        url,
        body: {'message': text}, 
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        // 🌟 3. 關鍵改動！把原本寫死的 'Restaurant Scenario'，換成這個！
        // (注意：這裡要把 const 拿掉喔)
        title: Text(
          widget.topicTitle,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                return Align(
                  alignment: msg['isUser']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!msg['isUser']) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryLighter,
                          child: Icon(
                            Icons.smart_toy,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.65,
                        ),
                        decoration: BoxDecoration(
                          color: msg['isUser']
                              ? AppColors.primary
                              : AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          msg['text'],
                          style: TextStyle(
                            color: msg['isUser']
                                ? Colors.white
                                : AppColors.textDark,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.mic, color: AppColors.primary),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: '輸入日文...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

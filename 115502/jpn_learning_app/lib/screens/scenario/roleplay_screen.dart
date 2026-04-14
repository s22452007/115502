import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:jpn_learning_app/utils/api_client.dart';

class RoleplayScreen extends StatefulWidget {
  final String topicTitle;

  const RoleplayScreen({Key? key, required this.topicTitle}) : super(key: key);
  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  // 🌟 1. 新增狀態：用來記錄 AI 是不是正在打字！
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // 🌟 2. 完美的冷啟動：一進畫面馬上給一句溫暖的歡迎詞，讓畫面不空白！
    _messages.add({
      'text': '歡迎來到「${widget.topicTitle}」！小精靈正在趕來的路上，請稍等一下喔...✨',
      'isUserMessage': false,
    });
  }

  // 🌟 2. 這是專屬的自動開場函數
  Future<void> _triggerAIOpening() async {
    // 🌟 3. 開始轉圈圈：告訴畫面 AI 正在思考
    setState(() {
      _isTyping = true;
    });
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/chat');
      final response = await http.post(
        url,
        body: {
          'message': '[幫我開場]',
          'topic': widget.topicTitle, // 把情境主題傳給後端
          'level': 'N4', // 你的日文等級
          'history': '',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _messages.add({'text': response.body, 'isUserMessage': false});
        });
      }
    } catch (e) {
      print('開場請求發生錯誤: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUserMessage': true});
    });

    _controller.clear();

    try {
      final url = Uri.parse('${ApiClient.baseUrl}/chat');
      print('🔍 準備發送請求到 $url');

      // 🌟 3. 把完整的包裹寄給 Python 廚師！
      final response = await http.post(
        url,
        body: {
          'message': text,
          'topic': widget.topicTitle,
          'level': 'N4',
          'history': '',
        },
      );

      print('🔍 收到後端狀態碼 ${response.statusCode}');

      if (response.statusCode == 200) {
        final aiReply = response.body;
        if (mounted) {
          setState(() {
            _messages.add({'text': aiReply, 'isUserMessage': false});
          });
        }
      } else {
        print('後端發生錯誤，狀態碼：${response.statusCode}');
      }
    } catch (e) {
      print('發送請求時發生錯誤: $e');
    }
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

                // 🌟 4. 這裡就是無敵防護罩！
                bool isUserMessage = msg['isUserMessage'] ?? false;
                String messageText = msg['text'] ?? ''; // 防止文字是 null 導致當機

                return Align(
                  // 👇 下面全部改用安全的 isUserMessage 變數來判斷！
                  alignment: isUserMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUserMessage) ...[
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
                          color: isUserMessage
                              ? AppColors.primary
                              : AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          messageText, // 👈 顯示安全的文字
                          style: TextStyle(
                            color: isUserMessage
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
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: AppColors.primary),
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
                  icon: const Icon(Icons.send, color: AppColors.primary),
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

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

  Future<void> _triggerAIOpening() async {
    setState(() {
      _isTyping = true;
    }); // 👈 1. 開始轉圈圈

    try {
      final url = Uri.parse('${ApiClient.baseUrl}/chat');
      final response = await http.post(
        url,
        body: {
          'message': '[幫我開場]',
          'topic': widget.topicTitle,
          'level': 'N4',
          'history': '',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          // 👈 2. 把開場白加進去
          _messages.add({'text': response.body, 'isUserMessage': false});
        });
      }
    } catch (e) {
      print('開場請求發生錯誤: $e');
    } finally {
      // 🌟 3. 強制關閉轉圈圈！
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUserMessage': true});
      _isTyping = true; // 👈 1. 開始轉圈圈
    });

    _controller.clear();

    try {
      final url = Uri.parse('${ApiClient.baseUrl}/chat');
      final response = await http.post(
        url,
        body: {
          'message': text,
          'topic': widget.topicTitle,
          'level': 'N4',
          'history': '',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final aiReply = response.body;
        setState(() {
          // 👈 2. 這裡只要專心把訊息加進去就好
          _messages.add({'text': aiReply, 'isUserMessage': false});
        });
      }
    } catch (e) {
      print('發送請求時發生錯誤: $e');
    } finally {
      // 🌟 3. 終極保險機制：不管成功還是失敗，最後一定強制關閉轉圈圈！
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
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
          // 🌟 5. 這裡就是畫出「正在思考中...」的地方！
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '🤖 AI 小精靈思考中...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

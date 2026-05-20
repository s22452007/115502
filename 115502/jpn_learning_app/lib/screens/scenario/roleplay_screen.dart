import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

class RoleplayScreen extends StatefulWidget {
  final String topicTitle;

  const RoleplayScreen({Key? key, required this.topicTitle}) : super(key: key);
  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  bool _isTyping = false;

  // 功能 2：假名標音開關狀態
  bool _showFurigana = false;

  // 功能 4：快捷回覆籌碼資料
  List<String> _quickReplies = [];

  // 使用量顯示狀態
  int _aiUsed = 0;
  int _aiMax = 5;
  int _aiExtra = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsageData(); // 初始化時抓取使用量

    _messages.add({
      'text': '歡迎來到「${widget.topicTitle}」！先開個頭吧！✨不知道如何開頭的話可以輸入：幫我開場',
      'isUserMessage': false,
      'furiganaText': '歡迎來到「${widget.topicTitle}」！先開個頭吧！✨', // 未來後端可提供標音版本
    });

    // 模擬：一進來先給幾個快捷選項
    _quickReplies = ['幫我開場', '請問規則是什麼？'];
  }

  // 抓取最新使用量
  Future<void> _fetchUsageData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final res = await ApiClient.getUsageStatus(userId);
    if (mounted && !res.containsKey('error')) {
      setState(() {
        _aiUsed = (res['ai_count_today'] as num?)?.toInt() ?? 0;
        _aiExtra = (res['ai_extra_count'] as num?)?.toInt() ?? 0;
        _aiMax = res['subscription_status'] == 'active' ? 30 : 5;
      });
    }
  }

  // 核心：每次傳訊息前先檢查額度
  Future<bool> _checkAILimit() async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null) return false;

    final res = await ApiClient.useAI(userId);
    if (!mounted) return false;

    final status = (res['_status'] as num?)?.toInt() ?? 200;
    
    // 遇到 403，跳出加購彈窗
    if (status == 403) {
      final used = (res['daily_ai'] as num?)?.toInt() ?? _aiUsed;
      final limit = (res['daily_limit'] as num?)?.toInt() ?? _aiMax;
      _showQuotaExceededDialog(used, limit);
      return false;
    } else {
      // 成功扣除次數 (200)，更新畫面
      setState(() {
        _aiUsed = (res['daily_ai'] as num?)?.toInt() ?? _aiUsed + 1;
        _aiExtra = (res['extra_count'] as num?)?.toInt() ?? _aiExtra;
      });
      // provider.updateAIUsage(countToday: _aiUsed, extraCount: _aiExtra);
      return true;
    }
  }

  // 次數用盡的加購彈窗
  void _showQuotaExceededDialog(int used, int limit) {
    final jPts = context.read<UserProvider>().jPts;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('今日對話次數已用完', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已使用 $used / $limit 次', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('花 30 點加購 +5 次（永久有效）', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text('目前點數：$jPts J-Pts',
                style: TextStyle(fontSize: 13, color: jPts >= 30 ? Colors.grey : Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6AA86B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: jPts < 30
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _buyExtraAndProceed();
                  },
            child: const Text('加購次數', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 花費點數購買次數的邏輯
  Future<void> _buyExtraAndProceed() async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null) return;

    final buyRes = await ApiClient.spendPoints(userId: userId, points: 30, feature: 'ai_extra');
    if (!mounted) return;

    if ((buyRes['_status'] as num?)?.toInt() != 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(buyRes['error'] ?? '購買失敗')));
      return;
    }

    if (buyRes['total_points'] != null) {
      provider.setJPts((buyRes['total_points'] as num).toInt());
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加購成功！請再次點擊發送。')));
    _fetchUsageData(); // 更新最新次數
  }

  Future<void> _triggerAIOpening() async {
    // 發送前檢查次數
    final canProceed = await _checkAILimit();
    if (!canProceed) return;

    setState(() {
      _isTyping = true;
    });
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
          _messages.add({'text': response.body, 'isUserMessage': false});
        });
      }
    } catch (e) {
      print('開場請求發生錯誤: $e');
    } finally {
      if (mounted)
        setState(() {
          _isTyping = false;
        });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 發送前檢查次數
    final canProceed = await _checkAILimit();
    if (!canProceed) return;

    setState(() {
      _messages.add({'text': text, 'isUserMessage': true});
      _isTyping = true;
      _quickReplies.clear(); // 發送訊息後清空快捷鍵
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
        /* 
          這裡未來需要配合後端改為解析 JSON 
          目前先寫死模擬資料，讓你看 UI 效果
          Map<String, dynamic> data = json.decode(response.body);
        */

        setState(() {
          _messages.add({
            'text': response.body, // 正常 API 回覆
            'isUserMessage': false,
            // 模擬功能 3：語法糾正 (未來從 data['correction'] 取得)
            'correction': text.contains('錯') ? '剛剛的句子動詞變化有點小問題喔！建議改成...' : null,
          });

          // 模擬功能 4：更新快捷選項 (未來從 data['quick_replies'] 取得)
          _quickReplies = ['そうですか', 'なるほど', 'もう少し教えて！'];
        });
      }
    } catch (e) {
      print('發送請求時發生錯誤: $e');
    } finally {
      if (mounted)
        setState(() {
          _isTyping = false;
        });
    }
  }

  // 功能 1：顯示單句點擊操作的 Bottom Sheet
  void _showBottomSheetOptions(BuildContext context, String messageText) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '針對此句的操作',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.translate, color: AppColors.primary),
                title: const Text('翻譯成中文'),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: 呼叫翻譯功能或顯示翻譯 UI
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_up, color: AppColors.primary),
                title: const Text('播放語音 (TTS)'),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: 呼叫 flutter_tts 播放
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_add,
                  color: AppColors.primary,
                ),
                title: const Text('收藏此句'),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: 呼叫後端 API 存入單字本或收藏庫
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已加入收藏！')));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
        title: Text(
          widget.topicTitle,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 功能 2：假名標音切換按鈕
        actions: [
          Row(
            children: [
              const Text(
                'ふりがな',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Switch(
                value: _showFurigana,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _showFurigana = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 頂部：次數顯示條
          Container(
            width: double.infinity,
            color: AppColors.primaryLighter.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              '今日對話：$_aiUsed / $_aiMax次' + (_aiExtra > 0 ? ' (額外$_aiExtra次)' : ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                bool isUserMessage = msg['isUserMessage'] ?? false;
                String messageText = msg['text'] ?? '';
                String? correction = msg['correction']; // 檢查是否有語法糾正

                return Align(
                  alignment: isUserMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUserMessage) ...[
                        const CircleAvatar(
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

                      // 外層包一個 Flexible 避免超出邊界
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUserMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // 功能 3：如果有語法糾正，顯示提示卡片
                            if (correction != null && !isUserMessage)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        correction,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // 功能 1：加上 GestureDetector 實現點擊選單
                            GestureDetector(
                              onTap: () {
                                if (!isUserMessage) {
                                  _showBottomSheetOptions(context, messageText);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isUserMessage
                                      ? AppColors.primary
                                      : AppColors.primaryLighter,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  // 配合功能 2：如果未來有 furiganaText 欄位且開關打開，就顯示標音版文字
                                  (_showFurigana &&
                                          msg.containsKey('furiganaText'))
                                      ? msg['furiganaText']
                                      : messageText,
                                  style: TextStyle(
                                    color: isUserMessage
                                        ? Colors.white
                                        : AppColors.textDark,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
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
          // 底部區域包裝在一起
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 功能 4：快捷回覆籌碼
              if (_quickReplies.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: _quickReplies.map((reply) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.primary),
                            label: Text(reply, style: const TextStyle(color: AppColors.primary)),
                            onPressed: () {
                              _controller.text = reply;
                              //如果是 "幫我開場" 呼叫 trigger
                              if (reply == '幫我開場') {
                                _triggerAIOpening();
                                _quickReplies.clear();
                                _controller.clear();
                              } else {
                                _sendMessage();
                              }
                            },
                          ),
                        )).toList(),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                          hintText: '輸入日文訊息...',
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
        ],
      ),
    );
  }
}
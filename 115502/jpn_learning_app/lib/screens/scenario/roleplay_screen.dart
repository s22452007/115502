import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';

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
  int _aiMax = 3;
  int _aiExtra = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsageData(); // 初始化時抓取使用量

    final userLevel = context.read<UserProvider>().japaneseLevel;
    final displayLevel = userLevel.isNotEmpty ? userLevel : 'N5';

    // --- 測試用：顯示目前讀取到的等級 ---
    _messages.add({
      'text': '*** 目前使用者的等級：$displayLevel ***\n\n歡迎來到「${widget.topicTitle}」！先開個頭吧！✨不知道如何開頭的話可以輸入：幫我開場',
      'isUserMessage': false,
      'furiganaText': '*** 目前使用者的等級：$displayLevel ***\n\n歡迎來到「${widget.topicTitle}」！先開個頭吧！✨', 
    });

    // --- 原本的開場訊息（未來不需要顯示等級時，解開這段並刪除上面那段即可） ---
    // _messages.add({
    //   'text': '歡迎來到「${widget.topicTitle}」！先開個頭吧！✨不知道如何開頭的話可以輸入：幫我開場',
    //   'isUserMessage': false,
    //   'furiganaText': '歡迎來到「${widget.topicTitle}」！先開個頭吧！✨', // 未來後端可提供標音版本
    // });

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
        _aiMax = res['subscription_status'] == 'active' ? 10 : 3;
      });
    }
  }

  // 核心：每次傳訊息前先檢查額度，onBoughtRetry 為購買成功後自動重試的動作
  Future<bool> _checkAILimit({void Function()? onBoughtRetry}) async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null) return false;

    final res = await ApiClient.useAI(userId);
    if (!mounted) return false;

    final status = (res['_status'] as num?)?.toInt() ?? 200;

    if (status == 403) {
      final used = (res['daily_ai'] as num?)?.toInt() ?? _aiUsed;
      final limit = (res['daily_limit'] as num?)?.toInt() ?? _aiMax;
      _showQuotaBottomSheet(used, limit, onBoughtRetry ?? () {});
      return false;
    } else {
      setState(() {
        _aiUsed = (res['daily_ai'] as num?)?.toInt() ?? 0;
        _aiExtra = (res['extra_count'] as num?)?.toInt() ?? 0;
      });
      return true;
    }
  }

  // 次數用盡的 BottomSheet
  void _showQuotaBottomSheet(int used, int limit, void Function() onBoughtRetry) {
    final provider = context.read<UserProvider>();
    final jPts = provider.jPts;
    final isPremium = provider.isPremium;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.smart_toy, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('今日AI對話次數已用完',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text(
                isPremium ? '訂閱版每天 10 次' : '免費版每天 3 次',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _buyExtraAndRetry(onBoughtRetry);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6AA86B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  jPts < 60
                      ? '點數不足（需 60 點，目前 $jPts 點）'
                      : '花 60 點加購 +5 次（永久）',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const StoreDashboardScreen()));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC6B13B),
                    side: const BorderSide(color: Color(0xFFC6B13B)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('升級訂閱  每天 10 次',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 花費 60 點加購 AI 次數，成功後自動執行 onRetry
  Future<void> _buyExtraAndRetry(void Function() onRetry) async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null) return;

    final buyRes = await ApiClient.spendPoints(userId: userId, points: 60, feature: 'ai_extra');
    if (!mounted) return;

    final status = (buyRes['_status'] as num?)?.toInt() ?? 0;
    if (status != 200) {
      final errMsg = buyRes['error']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg.contains('點數不足') ? '點數不足，請先購買點數' : errMsg),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (buyRes['total_points'] != null) {
      provider.setJPts((buyRes['total_points'] as num).toInt());
    }
    await _fetchUsageData();
    if (!mounted) return;
    onRetry(); // 自動重試原本的動作
  }

  Future<void> _triggerAIOpening() async {
    // 發送前檢查次數
    final canProceed = await _checkAILimit(onBoughtRetry: () { _triggerAIOpening(); });
    if (!canProceed) return;

    setState(() {
      _isTyping = true;
    });
    try {
      final userLevel = context.read<UserProvider>().japaneseLevel;
      final levelToPass = userLevel.isNotEmpty ? userLevel : 'N5';

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

        await _fetchUsageData(); // 開場成功後重新載入使用量
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
    final canProceed = await _checkAILimit(onBoughtRetry: () { _sendMessage(); });
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

        await _fetchUsageData(); // 訊息成功後重新載入使用量
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
          Builder(builder: (_) {
            final dailyRemaining = (_aiMax - _aiUsed).clamp(0, _aiMax);
            final effectiveRemaining = dailyRemaining + _aiExtra;
            final countColor = effectiveRemaining <= 0
                ? Colors.red.shade600
                : effectiveRemaining == 1
                    ? Colors.orange.shade700
                    : AppColors.primary;
            final extraText = _aiExtra > 0 ? ' 額外$_aiExtra次' : '';
            return Container(
              width: double.infinity,
              color: AppColors.primaryLighter.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                '今日對話：$_aiUsed / $_aiMax 次$extraText',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: countColor, fontWeight: FontWeight.bold),
              ),
            );
          }),

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
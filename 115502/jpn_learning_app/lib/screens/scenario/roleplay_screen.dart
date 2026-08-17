import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:jpn_learning_app/widgets/common/furigana_text.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';

class RoleplayScreen extends StatefulWidget {
  final String topicTitle;
  final String characterName; 

  const RoleplayScreen({
    Key? key,
    required this.topicTitle,
    required this.characterName, 
  }) : super(key: key);

  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  bool _isTyping = false;
  bool _showFurigana = false;
  List<String> _quickReplies = [];

  int _aiUsed = 0;
  int _aiMax = 3;
  int _aiExtra = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingText; 

  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false; 
  bool _isListening = false;   
  bool _speechJapanese = true; 

  @override
  void initState() {
    super.initState();
    _fetchUsageData(); 
    _initSpeech();     

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingText = null);
    });

    // 👉 1. 修改：一進來的歡迎訊息，把角色名字印出來讓使用者知道
    //    標記 isGreeting，組對話紀錄時要排除（它是介面說明，不是對話內容）
    _messages.add({
      'text': '歡迎來到「${widget.topicTitle}」！\n我是今天的對話對象「${widget.characterName}」✨\n不知道如何開頭的話可以點擊下方：幫我開場',
      'isUserMessage': false,
      'isGreeting': true,
    });

    _quickReplies = ['幫我開場', '請問規則是什麼？'];
  }

  @override
  void dispose() {
    _speech.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          print('語音辨識錯誤: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (e) {
      print('語音辨識初始化失敗: $e');
      _speechEnabled = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('此裝置不支援語音辨識，或未授權麥克風權限'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    final locale = _speechJapanese
        ? (kIsWeb ? 'ja-JP' : 'ja_JP')
        : (kIsWeb ? 'zh-TW' : 'zh_TW');
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: locale, 
        partialResults: true, 
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
    );
  }

  Future<void> _playTts(String text) async {
    final t = FuriganaText.cleanFuriganaForTts(text).trim();
    if (t.isEmpty) return;

    await _audioPlayer.stop();
    setState(() => _playingText = t);

    try {
      final url = Uri.parse('${ApiClient.baseUrl}/tts/synthesize');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': t}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bytes = base64Decode(data['audio_base64'] as String);
        await _audioPlayer.play(BytesSource(bytes));
      } else {
        setState(() => _playingText = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('語音合成失敗，請稍後再試'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      print('TTS 播放錯誤: $e');
      if (mounted) setState(() => _playingText = null);
    }
  }

  List<String> _splitSentences(String text) {
    final sentences = <String>[];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      for (final m in RegExp(r'[^。！？!?]+[。！？!?]*').allMatches(line)) {
        final s = m.group(0)!.trim();
        if (s.isNotEmpty) sentences.add(s);
      }
    }
    return sentences;
  }

  Future<void> _fetchUsageData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final res = await ApiClient.getUsageStatus(userId);
    if (mounted && !res.containsKey('error')) {
      setState(() {
        _aiUsed = (res['ai_count_today'] as num?)?.toInt() ?? 0;
        _aiExtra = (res['ai_extra_count'] as num?)?.toInt() ?? 0;
        _aiMax = res['is_premium'] == true ? 10 : 3;
      });
    }
  }

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
    } else if (status == 200) {
      setState(() {
        _aiUsed = (res['daily_ai'] as num?)?.toInt() ?? 0;
        _aiExtra = (res['extra_count'] as num?)?.toInt() ?? 0;
      });
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('連線失敗，無法確認使用次數，請稍後再試'),
        backgroundColor: Colors.redAccent,
      ));
      return false;
    }
  }

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
    onRetry(); 
  }

  // ==========================================
  // 💬 組出要送給 AI 的對話紀錄（讓 AI 記得前面聊過什麼）
  // ==========================================
  // 只取最近幾則，原因：
  //   1. 對話連貫性只需要最近的上下文
  //   2. 歷史越長，每次請求消耗的 token 越多，額度會燒得更快
  static const int _historyTurns = 8; // 最多帶入的訊息則數

  String _buildChatHistory() {
    // 排除開場的介面說明訊息
    final real = _messages.where((m) => m['isGreeting'] != true).toList();
    if (real.isEmpty) return '';

    // 只取最近 N 則
    final recent = real.length > _historyTurns
        ? real.sublist(real.length - _historyTurns)
        : real;

    final aiName = widget.characterName.isNotEmpty ? widget.characterName : '老師';

    return recent.map((m) {
      final isUser = m['isUserMessage'] == true;
      // 去掉 [漢字|假名] 標音再送出：對理解語意沒有幫助，卻會多花不少 token
      final text = FuriganaText.cleanFuriganaForTts(m['text']?.toString() ?? '').trim();
      return '${isUser ? "使用者" : aiName}：$text';
    }).join('\n');
  }

  Future<void> _triggerAIOpening() async {
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
          'level': levelToPass,
          // 👉 2. 修改：把角色名字傳給後端
          'character': widget.characterName,
          'history': _buildChatHistory(), // 中途再按開場時，讓 AI 知道前面聊過什麼
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _messages.add({'text': response.body, 'isUserMessage': false});
        });

        await _fetchUsageData(); 
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

    final canProceed = await _checkAILimit(onBoughtRetry: () { _sendMessage(); });
    if (!canProceed) return;

    // 先取得歷史紀錄，再把這次的新訊息加進畫面
    //（新訊息會用 message 參數單獨送出，不能重複出現在 history 裡）
    final history = _buildChatHistory();

    setState(() {
      _messages.add({'text': text, 'isUserMessage': true});
      _isTyping = true;
      _quickReplies.clear();
    });

    _controller.clear();

    try {
      final userLevel = context.read<UserProvider>().japaneseLevel;
      final levelToPass = userLevel.isNotEmpty ? userLevel : 'N5';

      final url = Uri.parse('${ApiClient.baseUrl}/chat');
      final response = await http.post(
        url,
        body: {
          'message': text,
          'topic': widget.topicTitle,
          'level': levelToPass,
          // 👉 3. 修改：把角色名字傳給後端
          'character': widget.characterName,
          'history': history, // 帶入最近的對話，讓 AI 記得前文
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _messages.add({
            'text': response.body, 
            'isUserMessage': false,
            'correction': text.contains('錯') ? '剛剛的句子動詞變化有點小問題喔！建議改成...' : null,
          });
          _quickReplies = ['そうですか', 'なるほど', 'もう少し教えて！'];
        });

        await _fetchUsageData(); 
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
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_up, color: AppColors.primary),
                title: const Text('播放語音 (TTS)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _playTts(messageText);
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

  bool _isTranslationLine(String line) =>
      line.startsWith('（') || line.startsWith('(');

  Widget _buildAiBubble(String displayText) {
    final cleaned = displayText.replaceAll('**', '').replaceAll('*', '');
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final japaneseOnly =
        lines.where((l) => !_isTranslationLine(l)).join('\n');
    final isWholePlaying =
        _playingText == FuriganaText.cleanFuriganaForTts(japaneseOnly).trim();

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 12, 44, 12),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) {
              if (_isTranslationLine(line)) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    FuriganaText.cleanFuriganaForTts(line),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              final sentences = _splitSentences(line);
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: sentences.map((s) {
                    final plain = FuriganaText.cleanFuriganaForTts(s);
                    final isPlaying = _playingText == plain;
                    final color =
                        isPlaying ? AppColors.primary : AppColors.textDark;
                    return GestureDetector(
                      onTap: () => _playTts(s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, bottom: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _showFurigana
                            ? FuriganaText(
                                text: s,
                                fontSize: 15,
                                textColor: color,
                              )
                            : Text(
                                plain,
                                style: TextStyle(color: color, fontSize: 15),
                              ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 8,
          right: 10,
          child: GestureDetector(
            onTap: () => _playTts(japaneseOnly),
            child: Icon(
              isWholePlaying ? Icons.graphic_eq : Icons.volume_up,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
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
        actions: [
          Row(
            children: [
              const Text(
                '漢字讀音',
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
                String? correction = msg['correction']; 

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

                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUserMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
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
                            GestureDetector(
                              onLongPress: () {
                                if (!isUserMessage) {
                                  _showBottomSheetOptions(context, messageText);
                                }
                              },
                              child: Builder(builder: (_) {
                                final String displayText = messageText;

                                if (isUserMessage) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      displayText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  );
                                }
                                return _buildAiBubble(displayText);
                              }),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.redAccent : AppColors.primary,
                      ),
                      tooltip: _isListening
                          ? '停止語音輸入'
                          : '語音輸入（${_speechJapanese ? '日語' : '中文'}）',
                      onPressed: _toggleListening,
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_isListening) {
                          await _speech.stop();
                        }
                        setState(() {
                          _speechJapanese = !_speechJapanese;
                          _isListening = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(
                          _speechJapanese ? '日' : '中',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? '🎤 聆聽中，請說${_speechJapanese ? '日語' : '中文'}...'
                              : '輸入日文訊息...',
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
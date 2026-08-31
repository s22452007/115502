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
  /// 從歷史紀錄接續對話時傳入既有場次 id；新對話則留 null
  final int? resumeSessionId;

  const RoleplayScreen({
    Key? key,
    required this.topicTitle,
    required this.characterName,
    this.resumeSessionId,
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

  // 對話紀錄場次 id（成功建立後，每次送出訊息都會帶上，後端才知道存到哪一場）
  int? _sessionId;
  bool _isLoadingHistory = false;

  // 訊息列表捲動控制：新訊息進來時自動捲到最下面
  final ScrollController _scrollController = ScrollController();
  // 輸入框焦點：按 Enter 送出後把游標留在輸入框，可以連續打字
  final FocusNode _inputFocusNode = FocusNode();

  /// 捲到對話最底部（等版面更新完再捲，才抓得到正確高度）
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUsageData(); 
    _initSpeech();     

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingText = null);
    });

    if (widget.resumeSessionId != null) {
      // 從歷史紀錄接續：載入先前的訊息
      _sessionId = widget.resumeSessionId;
      _isLoadingHistory = true;
      _loadPreviousMessages();
    } else {
      // 全新對話：顯示歡迎訊息並建立場次
      // 標記 isGreeting，組對話紀錄時要排除（它是介面說明，不是對話內容）
      _messages.add({
        'text': '歡迎來到「${widget.topicTitle}」！\n我是今天的對話對象「${widget.characterName}」✨\n不知道如何開頭的話可以點擊下方：幫我開場',
        'isUserMessage': false,
        'isGreeting': true,
      });
      _createSession();
    }

    _quickReplies = ['幫我開場', '請問規則是什麼？'];
  }

  @override
  void dispose() {
    _speech.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
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
  // 📚 對話紀錄：建立場次 / 載入先前訊息
  // ==========================================
  Future<void> _createSession() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return; // 訪客不留紀錄

    final id = await ApiClient.createChatSession(
      userId: userId,
      topic: widget.topicTitle,
      characterName: widget.characterName,
    );
    if (mounted) setState(() => _sessionId = id);
  }

  Future<void> _loadPreviousMessages() async {
    final data = await ApiClient.fetchChatSession(widget.resumeSessionId!);
    if (!mounted) return;

    if (data == null) {
      setState(() => _isLoadingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('載入對話紀錄失敗，可以直接繼續聊'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final messages = (data['messages'] as List?) ?? [];
    setState(() {
      _messages.addAll(messages.map((m) => {
            'text': m['content']?.toString() ?? '',
            'isUserMessage': m['role'] == 'user',
          }));
      _isLoadingHistory = false;
      // 接續對話時給幾個常用的回應選項
      if (_messages.isNotEmpty) {
        _quickReplies = ['そうですか', 'なるほど', 'もう少し教えて！'];
      }
    });
    _scrollToBottom(); // 接續對話時直接看到最新的訊息
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
          // 帶上 user_id：AI 若回覆失敗，後端會把剛扣掉的次數退還
          'user_id': (context.read<UserProvider>().userId ?? '').toString(),
          // 帶上 session_id：後端會把這次問答存進對話紀錄（失敗則不存）
          'session_id': (_sessionId ?? '').toString(),
          'history': _buildChatHistory(), // 中途再按開場時，讓 AI 知道前面聊過什麼
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _messages.add({'text': response.body, 'isUserMessage': false});
        });
        _scrollToBottom();

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
    _scrollToBottom();
    // 按 Enter 送出後把游標留在輸入框，使用者可以直接接著打下一句
    _inputFocusNode.requestFocus();

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
          // 帶上 user_id：AI 若回覆失敗，後端會把剛扣掉的次數退還
          'user_id': (context.read<UserProvider>().userId ?? '').toString(),
          // 帶上 session_id：後端會把這次問答存進對話紀錄（失敗則不存）
          'session_id': (_sessionId ?? '').toString(),
          'history': history, // 帶入最近的對話，讓 AI 記得前文
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // AI 會在回覆最前面附上文法訂正（有錯才有），把它拆出來單獨顯示
        final parsed = _extractCorrection(response.body);
        setState(() {
          _messages.add({
            'text': parsed.reply,
            'isUserMessage': false,
            'correction': parsed.correction,
          });
          _quickReplies = ['そうですか', 'なるほど', 'もう少し教えて！'];
        });
        _scrollToBottom();
      } else {
        // 伺服器錯誤時也要讓使用者知道，不能什麼都不顯示
        setState(() {
          _messages.add({
            'text': '訊息送不出去，請稍後再試一次！',
            'isUserMessage': false,
          });
        });
      }
      await _fetchUsageData(); // 無論成功失敗都更新次數（失敗時後端會退還）
    } catch (e) {
      print('發送請求時發生錯誤: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            'text': '網路連線失敗，請確認連線後再試一次！',
            'isUserMessage': false,
          });
        });
      }
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
                  // 只念日文句子，跳過中文說明與翻譯
                  _playTts(_japaneseLinesOf(messageText));
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

  // ==========================================
  // ✏️ 文法訂正：AI 會把訂正放在回覆的第一行，格式為
  //    [訂正]錯誤說法 → 正確說法（說明）
  //    這裡把它拆出來，讓它顯示在專屬的提示卡片而不是混在對話裡。
  // ==========================================
  ({String reply, String? correction}) _extractCorrection(String raw) {
    final lines = raw.split('\n');
    final index = lines.indexWhere((l) => l.trim().startsWith('[訂正]'));
    if (index == -1) {
      return (reply: raw, correction: null);
    }

    final correction =
        lines[index].trim().replaceFirst('[訂正]', '').trim();
    lines.removeAt(index);
    // 去掉訂正行後可能留下開頭空行
    final reply = lines.join('\n').replaceFirst(RegExp(r'^\s*\n+'), '');

    return (
      reply: reply.trim().isEmpty ? raw : reply,
      correction: correction.isEmpty ? null : correction,
    );
  }

  bool _isTranslationLine(String line) =>
      line.startsWith('（') || line.startsWith('(');

  // 判斷是否為日文句子：含有平假名或片假名即為日文。
  // 中文（含說明與翻譯）不會出現假名，藉此區分出「可點擊發音」的行，
  // 避免中文被送去日語 TTS 念出無意義的發音。
  static final RegExp _kanaRegExp = RegExp(r'[぀-ゟ゠-ヿ]');
  bool _isJapaneseLine(String line) =>
      !_isTranslationLine(line) && _kanaRegExp.hasMatch(line);

  // 從整則訊息中只取出日文行（供整段朗讀使用）
  String _japaneseLinesOf(String text) => text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && _isJapaneseLine(l))
      .join('\n');

  Widget _buildAiBubble(String displayText) {
    final cleaned = displayText.replaceAll('**', '').replaceAll('*', '');
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 整段播放時只念日文行（跳過中文說明與翻譯）
    final japaneseOnly = lines.where(_isJapaneseLine).join('\n');
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
              // 中文翻譯行：灰色小字、不可點擊
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
              // 中文說明行（教學模式的中文回應）：一般文字、不可點擊，
              // 因為日語 TTS 念中文只會發出聽不懂的音。
              if (!_isJapaneseLine(line)) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    FuriganaText.cleanFuriganaForTts(line),
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      height: 1.4,
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
    // 從歷史紀錄接續時，先顯示載入中，避免訊息突然跳出來
    if (_isLoadingHistory) {
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
                color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

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
              controller: _scrollController, // 讓新訊息可以自動捲到底
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '文法小提醒',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          // 訂正內容也可能含標音，顯示前先清掉
                                          Text(
                                            FuriganaText.cleanFuriganaForTts(
                                                correction),
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
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
                        focusNode: _inputFocusNode,
                        // 手機鍵盤右下角顯示「送出」而不是「完成」
                        textInputAction: TextInputAction.send,
                        // 按 Enter（或鍵盤送出鍵）直接送出
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
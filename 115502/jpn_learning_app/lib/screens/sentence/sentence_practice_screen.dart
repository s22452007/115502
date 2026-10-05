import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/sentence/sentence_history_screen.dart';
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart';
import 'package:jpn_learning_app/widgets/common/staged_progress_overlay.dart';
import 'package:jpn_learning_app/widgets/common/sentence_feedback.dart';

class SentencePracticeScreen extends StatefulWidget {
  /// 從「我的作業」進來時帶入作業 ID：題目改用老師指定的文法與單字，
  /// 批改完成後後端會自動繳交。一般練習為 null。
  final int? assignmentId;

  const SentencePracticeScreen({Key? key, this.assignmentId}) : super(key: key);

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  bool _isLoadingTask = true;
  bool _isEvaluating = false;

  String _grammarPoint = '';
  String _grammarMeaning = '';
  List<String> _examples = [];

  // 作業模式：老師指定的必用單字與作業標題
  bool get _isAssignment => widget.assignmentId != null;
  List<String> _requiredVocabs = [];
  String _assignmentTitle = '';

  List<Map<String, dynamic>> _allMyVocabs = [];
  List<String> _selectedVocabWords = [];

  final TextEditingController _sentenceController = TextEditingController();

  // 🌟 追蹤今日免費次數
  int _todayCount = 0;
  // 每日免費批改次數由後端依方案決定（免費版 3、Premium 10），載入題目時更新
  int _maxFreeCount = 3;

  @override
  void initState() {
    super.initState();
    _loadTaskAndVocabs();
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    super.dispose();
  }

  // 🌟 防彈版：獨立處理文法與單字，確保一個出錯不會波及另一個
  Future<void> _loadTaskAndVocabs() async {
    if (!mounted) return;

    // 確保點擊「下一題」時，畫面會重新轉圈圈
    setState(() => _isLoadingTask = true);

    final userId = context.read<UserProvider>().userId ?? 8;

    // ==========================================
    // 任務 1：先安全地獲取文法題目 (獨立 Try-Catch)
    //   作業模式：文法與必用單字來自老師設定，不抽隨機題
    //   一般模式：向後端抽今日題目
    // ==========================================
    try {
      if (_isAssignment) {
        final detail = await ApiClient.getAssignmentDetail(
          widget.assignmentId!,
          userId,
        );
        if (detail['status'] == 'success' && mounted) {
          final a = Map<String, dynamic>.from(detail['assignment'] ?? {});
          final config = Map<String, dynamic>.from(a['config'] ?? {});
          final required = List<String>.from(config['required_vocabs'] ?? []);
          setState(() {
            _assignmentTitle = a['title'] ?? '';
            _grammarPoint = config['grammar_point'] ?? '';
            _grammarMeaning = (a['instructions'] ?? '').toString().isNotEmpty
                ? a['instructions']
                : '請用這個文法造一個句子';
            _examples = [];
            _requiredVocabs = required;
            // 必用單字預先勾選，學生不用再自己找
            _selectedVocabWords = List<String>.from(required);
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入作業失敗：${detail['error'] ?? '未知錯誤'}')),
          );
        }
      } else {
        final taskResult = await ApiClient.getSentenceTask(userId);
        if (taskResult['status'] == 'success') {
          if (mounted) {
            setState(() {
              _grammarPoint = taskResult['data']['grammar'] ?? '';
              _grammarMeaning = taskResult['data']['meaning'] ?? '';
              _examples = List<String>.from(taskResult['data']['examples'] ?? []);
              _todayCount = taskResult['today_count'] ?? 0;
              _maxFreeCount = (taskResult['daily_limit'] as num?)?.toInt() ?? _maxFreeCount;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取文法發生例外: $e');
    }

    // ==========================================
    // 任務 2：接著獲取可以勾選的單字 (即使失敗也不影響文法顯示)
    //   收藏過的字 + 拍照辨識過的字，後端已去重複、收藏的排前面
    // ==========================================
    try {
      final List<Map<String, dynamic>> allVocabs = [];
      for (final v in await ApiClient.getPracticeWords(userId)) {
        final word = (v['word'] ?? '').toString();
        if (word.isEmpty) continue;
        allVocabs.add({
          'word': word,
          'meaning': v['meaning'] ?? '',
          'source': v['source'] ?? 'collected',
        });
      }

      // 作業指定的單字可能不在學生收藏裡，補進清單讓它能被顯示與勾選
      for (final w in _requiredVocabs) {
        if (!allVocabs.any((e) => e['word'] == w)) {
          allVocabs.insert(0, {'word': w, 'meaning': '作業指定單字', 'source': 'assignment'});
        }
      }

      if (mounted) {
        setState(() {
          _allMyVocabs = allVocabs;
        });
      }
    } catch (e) {
      debugPrint('❌ 獲取單字發生例外: $e');
    }

    // ==========================================
    // 任務 3：兩邊都跑完後，結束載入狀態
    // ==========================================
    if (mounted) {
      setState(() => _isLoadingTask = false);
    }
  }

  // 🌟 攔截次數與支付點數邏輯
  Future<void> _submitSentence({bool payWithPoints = false}) async {
    final sentence = _sentenceController.text.trim();
    if (sentence.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入造句！')));
      return;
    }

    // 判斷是否超過免費次數，且尚未同意支付點數。
    // 教育版學生沒有每日上限（後端也不會擋），前端不能先把他擋下來。
    final isEduStudent = context.read<UserProvider>().isEduStudent;
    if (!isEduStudent && _todayCount >= _maxFreeCount && !payWithPoints) {
      _showOutOfQuotaDialog();
      return;
    }

    setState(() => _isEvaluating = true);
    final userId = context.read<UserProvider>().userId ?? 8;

    final result = await ApiClient.evaluateSentence(
      userId: userId,
      grammarPoint: _grammarPoint,
      selectedVocabs: _selectedVocabWords,
      userSentence: sentence,
      payWithPoints: payWithPoints,
      assignmentId: widget.assignmentId,
    );

    if (!mounted) return;
    setState(() => _isEvaluating = false);

    if (result['status'] == 'success') {
      _todayCount++;

      // 如果是用點數支付的，立刻同步本地點數顯示扣 10 點
      if (payWithPoints) {
        final currentPts = context.read<UserProvider>().jPts ?? 0;
        context.read<UserProvider>().setJPts(currentPts - 10);
      }

      _showEvaluationResultDialog(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批改失敗：${result['error'] ?? '未知錯誤'}')),
      );
    }
  }

  // 🌟 額度耗盡導購對話框
  void _showOutOfQuotaDialog() {
    final userProvider = context.read<UserProvider>();
    if (userProvider.isEduStudent) return;
    final currentPts = userProvider.jPts ?? 0;
    final int cost = 10;
    final bool hasEnoughPoints = currentPts >= cost;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 60),
                const SizedBox(height: 16),
                const Text(
                  '今日免費次數已用盡',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  hasEnoughPoints
                      ? '您今天的 $_maxFreeCount 次免費額度已用完。\n是否花費 $cost J-pts 進行本次批改？\n(若造句完美，有機會賺回 50 點喔！)'
                      : '您今天的 $_maxFreeCount 次免費額度已用完，且目前點數不足 ($currentPts/$cost)。\n請前往商城補充點數繼續挑戰！',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '稍後再說',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (hasEnoughPoints) {
                            _submitSentence(payWithPoints: true);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const StoreDashboardScreen(),
                              ),
                            );
                          }
                        },
                        child: Text(
                          hasEnoughPoints ? '支付 $cost 點' : '前往商城',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVocabSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '選擇要挑戰的單字',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '句子每用到一個勾選的單字，獎勵 +10 點（最多 3 個）',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: _allMyVocabs.isEmpty
                          ? const Center(
                              child: Text(
                                '還沒有可以選的單字喔！\n先去拍照辨識，或在文章裡收藏單字吧。',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _allMyVocabs.length,
                              itemBuilder: (context, index) {
                                final vocab = _allMyVocabs[index];
                                final word = vocab['word'] ?? '';
                                final isSelected = _selectedVocabWords.contains(
                                  word,
                                );
                                final source = vocab['source'];
                                final fromPhoto = source == 'photo';
                                final tag = source == 'assignment' ? '作業指定' : (fromPhoto ? '拍過' : '已收藏');
                                return CheckboxListTile(
                                  activeColor: AppColors.primary,
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          word,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // 標出來源：收藏過的字 / 拍照辨識過的字
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: fromPhoto ? AppColors.lightBg : Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: fromPhoto ? AppColors.textSubtle : Colors.amber.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(vocab['meaning'] ?? ''),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      if (value == true)
                                        _selectedVocabWords.add(word);
                                      else
                                        _selectedVocabWords.remove(word);
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '確定',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 獎勵點數下方的單字加分說明：用到的單字 +10，選了沒用到的也列出來
  Widget _buildVocabBonusNote(int bonus, List<String> used, List<String> unused) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bonus > 0 ? Colors.amber.withOpacity(0.12) : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (bonus > 0)
            Text(
              '單字加分 +$bonus 點（用到：${used.join('、')}）',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber.shade800),
            ),
          if (unused.isNotEmpty)
            Text(
              '選了但沒用到：${unused.join('、')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
        ],
      ),
    );
  }

  void _showEvaluationResultDialog(Map<String, dynamic> result) {
    final score = result['score'] ?? 0;
    final points = result['points_earned'] ?? 0;
    // corrected_ruby 是含讀音標記的版本（舊版後端沒有就用 corrected_sentence）
    final correctedSentence =
        (result['corrected_ruby'] ?? result['corrected_sentence'] ?? '').toString();
    final feedback = (result['strict_feedback'] ?? '').toString();
    final summary = (result['summary'] ?? '').toString();
    final translation = (result['translation'] ?? '').toString();
    final corrections = (result['corrections'] as List?) ?? const [];
    final isCorrect = result['is_grammar_correct'] ?? false;
    // 選用單字加分：用到幾個、哪些沒用到（舊版後端沒有這些欄位就不顯示）
    final vocabBonus = (result['vocab_bonus'] as num?)?.toInt() ?? 0;
    final usedVocabs = List<String>.from(result['used_vocabs'] ?? const []);
    final unusedVocabs = List<String>.from(result['unused_vocabs'] ?? const []);
    // 作業模式才有：後端自動繳交的結果
    final Map<String, dynamic>? assignmentResult =
        (result['assignment_result'] as Map?)?.cast<String, dynamic>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect
                        ? Icons.verified_rounded
                        : Icons.edit_note_rounded,
                    color: isCorrect ? const Color(0xFF10B981) : Colors.orange,
                    size: 70,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCorrect ? '太棒了！造句非常完美！' : '還有進步空間喔！',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (assignmentResult != null) ...[
                    const SizedBox(height: 12),
                    _buildAssignmentResultBanner(assignmentResult),
                  ],
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'AI 評分',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: score >= 60
                                  ? AppColors.primary
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      Column(
                        children: [
                          const Text(
                            '可領取獎勵',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '$points 點',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (vocabBonus > 0 || unusedVocabs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildVocabBonusNote(vocabBonus, usedVocabs, unusedVocabs),
                  ],
                  const Divider(height: 30),

                  // 總評一句 + 你的句子 → 修改建議 → 參考句子（與拍照後的練習造句共用）
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textDark),
                    ),
                  SentenceFeedbackSections(
                    userSentence: _sentenceController.text,
                    corrections: corrections,
                    correctedSentence: correctedSentence,
                    translation: translation,
                    isCorrect: isCorrect == true,
                    fallbackFeedback: feedback,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _loadTaskAndVocabs();
                            _sentenceController.clear();
                            _selectedVocabWords.clear();
                          },
                          child: Text(
                            _isAssignment ? '再試一次' : '下一題',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SentenceHistoryScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '去領點數',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 作業繳交結果的提示條：交成功是綠色，沒交到（例如少用指定單字）是橘色並說明原因
  Widget _buildAssignmentResultBanner(Map<String, dynamic> r) {
    final bool submitted = r['submitted'] == true;
    final String text = submitted
        ? '已繳交作業${_assignmentTitle.isNotEmpty ? '「$_assignmentTitle」' : ''}'
        : '尚未交到作業：${r['error'] ?? '請再試一次'}';
    final Color color = submitted ? const Color(0xFF10B981) : Colors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            submitted ? Icons.assignment_turned_in_rounded : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
        title: Text(
          _isAssignment ? '作業：造句挑戰' : '造句挑戰',
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isLoadingTask)
            Builder(
              builder: (context) {
                // 教育版學生沒有每日上限：改顯示「不限次數」，也不會變紅
                final isEduStudent = context.watch<UserProvider>().isEduStudent;
                final outOfQuota =
                    !isEduStudent && _todayCount >= _maxFreeCount;
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: outOfQuota
                          ? Colors.red.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isEduStudent
                          ? '不限次數'
                          : '免費: ${_todayCount < _maxFreeCount ? _maxFreeCount - _todayCount : 0}/$_maxFreeCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: outOfQuota ? Colors.red : AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SentenceHistoryScreen(),
              ),
            ),
            tooltip: '歷史紀錄與獎勵',
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 批改進行中時蓋一層分階段進度，讓使用者知道 AI 做到哪，
      // 而不是只有按鈕上一個轉圈。用 Stack 而非跳新畫面，
      // 這樣使用者輸入的造句不會被清掉，批改失敗也能直接重試。
      body: Stack(
        children: [
          _isLoadingTask
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '指定文法',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _grammarPoint,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '意思：$_grammarMeaning',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (_examples.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.lightbulb_circle,
                                          size: 20,
                                          color: Colors.amber,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '參考例句',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ..._examples
                                        .map(
                                          (ex) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '• ',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    ex,
                                                    style: const TextStyle(
                                                      color: Color(0xFF475569),
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        '選用我學過的單字（選填，每用到一個 +10 點）',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showVocabSelectionDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedVocabWords.isEmpty
                                      ? '點擊勾選你想練習的單字...'
                                      : '已選用：${_selectedVocabWords.join(", ")}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedVocabWords.isEmpty
                                        ? const Color(0xFF94A3B8)
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        '輸入你的造句',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sentenceController,
                        maxLines: 4,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: '請輸入日文...',
                          hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isEvaluating ? null : _submitSentence,
                          child: _isEvaluating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  '送出給 AI 批改',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

          // 階段順序對應後端 /api/sentence/evaluate 的實際流程：
          // 收到請求 → Gemini 批改文法 → 評分 → 寫入練習紀錄
          if (_isEvaluating)
            const StagedProgressOverlay(
              stages: [
                ProgressStage(
                  icon: Icons.send_rounded,
                  label: '正在送出你的造句…',
                  seconds: 2,
                ),
                ProgressStage(
                  icon: Icons.spellcheck_rounded,
                  label: 'AI 正在檢查文法與助詞…',
                  seconds: 8,
                ),
                ProgressStage(
                  icon: Icons.grading_rounded,
                  label: '正在評分並寫下建議…',
                  seconds: 6,
                ),
                ProgressStage(
                  icon: Icons.bookmark_added_rounded,
                  label: '正在記錄這次的練習成果…',
                  seconds: 999,
                ),
              ],
              reassureText: 'AI 正在仔細看你的句子，請稍候…',
            ),
        ],
      ),
    );
  }
}

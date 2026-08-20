import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/sentence/sentence_history_screen.dart'; 
import 'package:jpn_learning_app/screens/premium/store_dashboard_screen.dart'; 

class SentencePracticeScreen extends StatefulWidget {
  const SentencePracticeScreen({Key? key}) : super(key: key);

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  bool _isLoadingTask = true;
  bool _isEvaluating = false;
  
  String _grammarPoint = '';
  String _grammarMeaning = '';
  List<String> _examples = [];
  
  List<Map<String, dynamic>> _allMyVocabs = [];
  List<String> _selectedVocabWords = [];
  
  final TextEditingController _sentenceController = TextEditingController();

  // 🌟 追蹤今日免費次數
  int _todayCount = 0;
  final int _maxFreeCount = 5;

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
    // ==========================================
    try {
      final taskResult = await ApiClient.getSentenceTask(userId);
      if (taskResult['status'] == 'success') {
        if (mounted) {
          setState(() {
            _grammarPoint = taskResult['data']['grammar'] ?? '';
            _grammarMeaning = taskResult['data']['meaning'] ?? '';
            _examples = List<String>.from(taskResult['data']['examples'] ?? []);
            _todayCount = taskResult['today_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取文法發生例外: $e');
    }

    // ==========================================
    // 任務 2：接著獲取收藏單字 (即使失敗也不影響文法顯示)
    // ==========================================
    try {
      List<Map<String, dynamic>> allVocabs = [];
      final foldersResult = await ApiClient.fetchUserFavorites(userId);
      
      if (foldersResult.containsKey('favorites') || foldersResult.containsKey('folders')) {
        final folders = foldersResult['favorites'] ?? foldersResult['folders'] ?? [];
        for (var folder in folders) {
          final folderId = folder['id'];
          final vResult = await ApiClient.getFolderVocabs(userId, folderId: folderId);
          if (vResult.containsKey('vocabs')) {
            for (var v in vResult['vocabs']) {
              final word = v['word'] ?? v['kanji'] ?? '';
              final meaning = v['meaning'] ?? '';
              if (word.isNotEmpty && !allVocabs.any((element) => element['word'] == word)) {
                allVocabs.add({'word': word, 'meaning': meaning});
              }
            }
          }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先輸入造句！')));
      return;
    }

    // 判斷是否超過免費次數，且尚未同意支付點數
    if (_todayCount >= _maxFreeCount && !payWithPoints) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('批改失敗：${result['error'] ?? '未知錯誤'}')));
    }
  }

  // 🌟 額度耗盡導購對話框
  void _showOutOfQuotaDialog() {
    final userProvider = context.read<UserProvider>();
    final currentPts = userProvider.jPts ?? 0;
    final int cost = 10;
    final bool hasEnoughPoints = currentPts >= cost;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 60),
                const SizedBox(height: 16),
                const Text('今日免費次數已用盡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  hasEnoughPoints 
                    ? '您今天的 $_maxFreeCount 次免費額度已用完。\n是否花費 $cost J-pts 進行本次批改？\n(若造句完美，有機會賺回 50 點喔！)'
                    : '您今天的 $_maxFreeCount 次免費額度已用完，且目前點數不足 ($currentPts/$cost)。\n請前往商城補充點數繼續挑戰！',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey[300]!)),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('稍後再說', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0),
                        onPressed: () {
                          Navigator.pop(context);
                          if (hasEnoughPoints) {
                            _submitSentence(payWithPoints: true);
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const StoreDashboardScreen()));
                          }
                        },
                        child: Text(hasEnoughPoints ? '支付 $cost 點' : '前往商城', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('選擇要挑戰的單字', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('用越多指定單字，總分越高！', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const Divider(height: 24),
                    Expanded(
                      child: _allMyVocabs.isEmpty
                          ? const Center(child: Text('單字本裡面還沒有單字喔！\n請先去閱讀文章收藏單字。', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _allMyVocabs.length,
                              itemBuilder: (context, index) {
                                final vocab = _allMyVocabs[index];
                                final word = vocab['word'] ?? '';
                                final isSelected = _selectedVocabWords.contains(word);
                                return CheckboxListTile(
                                  activeColor: AppColors.primary,
                                  title: Text(word, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(vocab['meaning'] ?? ''),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      if (value == true) _selectedVocabWords.add(word);
                                      else _selectedVocabWords.remove(word);
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
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('確定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showEvaluationResultDialog(Map<String, dynamic> result) {
    final score = result['score'] ?? 0;
    final points = result['points_earned'] ?? 0;
    final correctedSentence = result['corrected_sentence'] ?? '';
    final feedback = result['strict_feedback'] ?? '';
    final isCorrect = result['is_grammar_correct'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect ? Icons.verified_rounded : Icons.edit_note_rounded, 
                    color: isCorrect ? const Color(0xFF10B981) : Colors.orange, 
                    size: 70
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCorrect ? '太棒了！造句非常完美！' : '還有進步空間喔！', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text('AI 評分', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('$score', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: score >= 60 ? AppColors.primary : Colors.red)),
                        ],
                      ),
                      Container(height: 40, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 24)),
                      Column(
                        children: [
                          const Text('可領取獎勵', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('$points 點', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.amber)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('完美句子建議：', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 8),
                        Text(correctedSentence, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        const Text('嚴格老師的點評：', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 8),
                        Text(feedback, style: const TextStyle(height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: () {
                            Navigator.pop(context); 
                            _loadTaskAndVocabs(); 
                            _sentenceController.clear();
                            _selectedVocabWords.clear();
                          },
                          child: const Text('下一題', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SentenceHistoryScreen()));
                          },
                          child: const Text('去領點數', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
        title: const Text('造句挑戰', style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          if (!_isLoadingTask)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _todayCount >= _maxFreeCount ? Colors.red.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '免費: ${_todayCount < _maxFreeCount ? _maxFreeCount - _todayCount : 0}/$_maxFreeCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _todayCount >= _maxFreeCount ? Colors.red : AppColors.primary,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SentenceHistoryScreen())),
            tooltip: '歷史紀錄與獎勵',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingTask
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('指定文法', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        const SizedBox(height: 12),
                        Text(_grammarPoint, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
                        const SizedBox(height: 8),
                        Text('意思：$_grammarMeaning', style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        
                        if (_examples.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lightbulb_circle, size: 20, color: Colors.amber),
                                    SizedBox(width: 6),
                                    Text('參考例句', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ..._examples.map((ex) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Expanded(child: Text(ex, style: const TextStyle(color: Color(0xFF475569), height: 1.5))),
                                    ],
                                  ),
                                )).toList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('選用我的單字本 (選填，可加分)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
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
                          const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedVocabWords.isEmpty ? '點擊勾選你想練習的單字...' : '已選用：${_selectedVocabWords.join(", ")}',
                              style: TextStyle(fontSize: 15, color: _selectedVocabWords.isEmpty ? const Color(0xFF94A3B8) : AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text('輸入你的造句', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sentenceController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 18, color: Color(0xFF2C3E50), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '請輸入日文...',
                      hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isEvaluating ? null : _submitSentence,
                      child: _isEvaluating
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('送出給 AI 批改', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
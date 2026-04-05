import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/auth/test_result_screen.dart';

class QuickTestScreen extends StatefulWidget {
  const QuickTestScreen({Key? key}) : super(key: key);

  @override
  State<QuickTestScreen> createState() => _QuickTestScreenState();
}

class _QuickTestScreenState extends State<QuickTestScreen> {
  int _currentIndex = 0;
  int? _selectedAnswerIndex;
  
  // 紀錄每一題是否答對
  final List<bool> _results = [];
  bool _isLoading = false;

  // 10題階梯題庫 (Q1~Q2:N5, Q3~Q4:N4, Q5~Q6:N3, Q7~Q8:N2, Q9~Q10:N1)
  final List<Map<String, dynamic>> _questions = [
    {'context': 'N5 - 基礎字彙', 'question': '「蘋果」的日文是？', 'options': ['A. みかん', 'B. りんご', 'C. いちご', 'D. ぶどう'], 'correctIndex': 1},
    {'context': 'N5 - 基礎語法', 'question': '私は学生____。', 'options': ['A. だ', 'B. です', 'C. ます', 'D. ある'], 'correctIndex': 1},
    {'context': 'N4 - 初級應用', 'question': '窓が____います。', 'options': ['A. 開けて', 'B. 開いて', 'C. 開く', 'D. 開かない'], 'correctIndex': 1},
    {'context': 'N4 - 初級應用', 'question': '日本へ____つもりです。', 'options': ['A. 行き', 'B. 行って', 'C. 行く', 'D. 行った'], 'correctIndex': 2},
    {'context': 'N3 - 中級語法', 'question': '先生に____。 (被老師稱讚了)', 'options': ['A. 褒めました', 'B. 褒めさせました', 'C. 褒められました', 'D. 褒めてもらいました'], 'correctIndex': 2},
    {'context': 'N3 - 中級應用', 'question': '健康の____、毎日運動しています。', 'options': ['A. ために', 'B. ように', 'C. そうに', 'D. ほどに'], 'correctIndex': 0},
    {'context': 'N2 - 高級語法', 'question': '日本____、やっぱり桜ですね。', 'options': ['A. というと', 'B. といえば', 'C. としたら', 'D. にしては'], 'correctIndex': 1},
    {'context': 'N2 - 高級應用', 'question': '時間が経つ____、忘れられていく。', 'options': ['A. につれて', 'B. にともなって', 'C. にしたがって', 'D. にはんして'], 'correctIndex': 0},
    {'context': 'N1 - 流利表達', 'question': 'これは難しいと____。', 'options': ['A. 言わざるを得ない', 'B. 言うまでもない', 'C. 言うに及ばない', 'D. 言うべきではない'], 'correctIndex': 0},
    {'context': 'N1 - 流利表達', 'question': '雨が____行く。', 'options': ['A. 降ろうが降るまいが', 'B. 降ったり降らなかったり', 'C. 降ると降らないと', 'D. 降っても降らなくても'], 'correctIndex': 0},
  ];

  Future<void> _nextQuestion() async {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請選擇一個答案喔！')));
      return;
    }

    // 判斷防猜機制：選了索引 4 (即選項 E) 直接視為錯誤
    bool isCorrect = false;
    if (_selectedAnswerIndex != 4) {
      isCorrect = (_selectedAnswerIndex == _questions[_currentIndex]['correctIndex']);
    }
    _results.add(isCorrect);

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
      });
    } else {
      // 測驗結束，打後端 API 進行判定
      setState(() => _isLoading = true);
      
      final currentUserId = context.read<UserProvider>().userId ?? 1;
      final response = await ApiClient.submitQuizResults(currentUserId, _results);
      
      // 從後端拿回乾淨的等級碼 ('N5' ~ 'N1')
      final levelCode = response['level'] ?? 'N5';
      
      if (context.mounted) {
        context.read<UserProvider>().setJapaneseLevel(levelCode);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TestResultScreen(levelCode: levelCode)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
    }

    final currentQ = _questions[_currentIndex];
    
    // 【防猜機制】動態在結尾加上選項 E
    final List<String> displayOptions = List.from(currentQ['options']);
    displayOptions.add('E. 我還沒學過這個');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text('程度測驗 (${_currentIndex + 1}/${_questions.length})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Text(currentQ['question'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5)),
                      const SizedBox(height: 32),

                      ...List.generate(displayOptions.length, (index) {
                        final isSelected = _selectedAnswerIndex == index;
                        // 若是選項E，給予不同的外觀視覺
                        final isOptionE = (index == 4); 

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () => setState(() => _selectedAnswerIndex = index),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? (isOptionE ? Colors.grey.shade400 : Colors.green.withOpacity(0.6)) 
                                    : (isOptionE ? Colors.grey.shade100 : Colors.green.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? (isOptionE ? Colors.grey.shade600 : Colors.green) 
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                displayOptions[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isOptionE && !isSelected ? Colors.grey.shade600 : (isSelected ? Colors.white : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(_currentIndex == _questions.length - 1 ? '完成測驗' : '下一題', 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
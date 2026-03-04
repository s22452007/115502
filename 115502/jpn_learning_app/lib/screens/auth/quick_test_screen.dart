import 'package:flutter/material.dart';
// import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/test_result_screen.dart';

class QuickTestScreen extends StatefulWidget {
  const QuickTestScreen({Key? key}) : super(key: key);

  @override
  State<QuickTestScreen> createState() => _QuickTestScreenState();
}

class _QuickTestScreenState extends State<QuickTestScreen> {
  // 記錄目前在第幾題 (0代表第一題)
  int _currentIndex = 0;
  // 記錄使用者目前選了哪個選項 (null代表還沒選)
  int? _selectedAnswerIndex;
  // 記錄總分
  int _score = 0;

  // 模擬題庫 (剛好 5 題，每題 20 分)
  final List<Map<String, dynamic>> _questions = [
    {
      'context': '情境題：便利商店',
      'question': '店員問：お弁当は温めますか？\n你想回答：好的，麻煩了。\n該選哪一個？',
      'options': ['A. はい、お願いします。', 'B. いいえ、結構です', 'C. 温めています。'],
      'correctIndex': 0,
    },
    {
      'context': '情境題：自我介紹',
      'question': '想向初次見面的人說「請多指教」，該怎麼說？',
      'options': ['A. ありがとう', 'B. よろしくお願いします', 'C. ごめんなさい'],
      'correctIndex': 1,
    },
    {
      'context': '情境題：餐廳點餐',
      'question': '想點菜時呼喚服務生，最適合的說法是？',
      'options': ['A. すみません', 'B. もしもし', 'C. こんにちは'],
      'correctIndex': 0,
    },
    {
      'context': '情境題：購物',
      'question': '想問「這個多少錢？」，該怎麼說？',
      'options': ['A. これはなんですか？', 'B. これはいくらですか？', 'C. これはどこですか？'],
      'correctIndex': 1,
    },
    {
      'context': '情境題：道別',
      'question': '跟朋友道別時，通常會說什麼？',
      'options': ['A. おはよう', 'B. いただきます', 'C. じゃあね'],
      'correctIndex': 2,
    },
  ];

  // 點擊下一題的邏輯
  void _nextQuestion() {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇一個答案喔！')),
      );
      return;
    }

    // 檢查答案是否正確，正確就加 20 分
    if (_selectedAnswerIndex == _questions[_currentIndex]['correctIndex']) {
      _score += 20; 
    }

    if (_currentIndex < _questions.length - 1) {
      // 如果還沒到最後一題，就進入下一題，並清空選擇
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null; 
      });
    } else {
      // 已經是最後一題，準備跳轉到結果頁
      print('測驗結束！總分：$_score');
      
      // 把分數傳遞給測驗結果頁
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TestResultScreen(score: _score),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('測驗完成！你的分數是 $_score 分，準備進入結果頁')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = _questions[_currentIndex];
    // 判斷是否為最後一題
    final isLastQuestion = _currentIndex == _questions.length - 1;

    return Scaffold(
      backgroundColor: Colors.white, // AppColors.white
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // --- 上半部：題目與選項 ---
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      // 動態顯示進度
                      Text(
                        '快速測驗(${_currentIndex + 1}/${_questions.length})',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // 情境標籤 (依照你的設計圖，是一個外框線的圓角矩形)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green), // AppColors.primary
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentQ['context'],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 題目文字
                      Text(
                        currentQ['question'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 32),

                      // 動態產生選項按鈕
                      ...List.generate(currentQ['options'].length, (index) {
                        final isSelected = _selectedAnswerIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedAnswerIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.green.withOpacity(0.6) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.green : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                currentQ['options'][index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected ? Colors.white : Colors.black87,
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

              // --- 下半部：底部按鈕 ---
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // AppColors.primary
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  // 如果是最後一題，按鈕文字會自動變成「完成測驗」
                  isLastQuestion ? '完成測驗' : '下一題',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
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
  
  // 改為空陣列，等待 API 載入
  List<dynamic> _questions = [];
  final List<bool> _results = [];
  
  bool _isLoading = true; // 狀態：是否正在載入題目
  bool _isSubmitting = false; // 狀態：是否正在結算成績

  @override
  void initState() {
    super.initState();
    _loadQuestionsFromDB(); // 畫面初始化時去撈題目
  }

  // 呼叫 API 拿題目
  Future<void> _loadQuestionsFromDB() async {
    final questions = await ApiClient.fetchQuizQuestions();
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      
      if (_questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('題庫載入失敗，請確認已執行 seed.py 並重啟後端')),
        );
      }
    }
  }

  Future<void> _nextQuestion() async {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請選擇一個答案喔！')));
      return;
    }

    // 防猜機制：選了索引 4 (即選項 E) 直接視為錯誤
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
      // 測驗結束，打後端 API 進行 Fail-Stop 判定
      setState(() => _isSubmitting = true);
      
      final currentUserId = context.read<UserProvider>().userId ?? 1;
      final response = await ApiClient.submitQuizResults(currentUserId, _results);
      
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
    // 載入中或結算中，顯示轉圈圈
    if (_isLoading || _isSubmitting || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              Text(_isSubmitting ? 'AI 正在為您判定程度...' : '正在為您抽取專屬題庫...'),
            ],
          ),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    
    // 【防猜機制】動態在結尾加上選項 E
    // 注意：因為資料庫傳來的 options 是 List<dynamic>，要先轉型再添加
    final List<String> displayOptions = List<String>.from(currentQ['options']);
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
                      Text('程度測驗 (${_currentIndex + 1}/${_questions.length})', 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 24),
                      
                      // 顯示由資料庫傳來的 context (例如：第一階段：超級新手 (N5))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentQ['context'] ?? '',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(currentQ['question'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5)),
                      const SizedBox(height: 32),

                      ...List.generate(displayOptions.length, (index) {
                        final isSelected = _selectedAnswerIndex == index;
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
                                  color: isSelected ? (isOptionE ? Colors.grey.shade600 : Colors.green) : Colors.transparent,
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
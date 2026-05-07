import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart'; // 🌟 引入 AppColors
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
  
  List<dynamic> _questions = [];
  final List<bool> _results = [];
  
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestionsFromDB();
  }

  Future<void> _loadQuestionsFromDB() async {
    final questions = await ApiClient.fetchQuizQuestions();
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      if (_questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('題庫載入失敗，請確認已執行 seed.py')),
        );
      }
    }
  }

  Future<void> _nextQuestion() async {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請選擇一個答案喔！')));
      return;
    }

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
    // --- 載入與結算畫面優化 ---
    if (_isLoading || _isSubmitting || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background, // 🌟 統一背景色
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _isSubmitting ? 'AI 正在為您判定程度...' : '正在抽取專屬題庫...',
                style: const TextStyle(
                  color: AppColors.primary, 
                  fontWeight: FontWeight.bold,
                  fontFamily: '微軟正黑體'
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    final List<String> displayOptions = List<String>.from(currentQ['options']);
    displayOptions.add('E. 我還沒學過這個');

    return Scaffold(
      backgroundColor: AppColors.background, // 🌟 統一背景色
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32), // 🌟 統一 32 邊距
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 🌟 改為左對齊
            children: [
              const SizedBox(height: 8),
              
              // 🌟 自定義線條進度條
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              
              const SizedBox(height: 32),

              // 🌟 這裡暫時保留舊有的 UI 結構，下個 Commit 會處理問題與選項的樣式
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第 ${_currentIndex + 1} 題 / 共 ${_questions.length} 題',
                        style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        currentQ['question'],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 32),
                      
                      // 原始選項按鈕 (Commit 3 會重構)
                      ...List.generate(displayOptions.length, (index) {
                        return ListTile(
                          title: Text(displayOptions[index]),
                          leading: Radio<int>(
                            value: index,
                            groupValue: _selectedAnswerIndex,
                            onChanged: (val) => setState(() => _selectedAnswerIndex = val),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // 原始按鈕 (Commit 4 會重構)
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
                ),
                child: Text(_currentIndex == _questions.length - 1 ? '完成測驗' : '下一題'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
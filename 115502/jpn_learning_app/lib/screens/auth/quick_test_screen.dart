import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
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

  // 🌟 統一動畫參數：與程度選擇頁面保持一致
  static const _syncDuration = Duration(milliseconds: 280);
  static const _syncCurve = Curves.easeOutCubic;

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
    if (_isLoading || _isSubmitting || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _isSubmitting ? 'AI 正在為您判定程度...' : '正在抽取專屬題庫...',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              
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

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentQ['context'] ?? '',
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        '第 ${_currentIndex + 1} 題',
                        style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        currentQ['question'],
                        style: const TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // 🌟 Commit 3 核心：帶有動畫的選項卡片
                      ...List.generate(displayOptions.length, (index) {
                        final isSelected = _selectedAnswerIndex == index;
                        final isOptionE = (index == 4);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildSyncedOptionCard(
                            text: displayOptions[index],
                            isSelected: isSelected,
                            isOptionE: isOptionE,
                            onTap: () => setState(() => _selectedAnswerIndex = index),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // 底部按鈕 (下個 Commit 將重構)
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

  // 🌟 核心組件：與程度選擇頁面完全同步的選項卡片
  Widget _buildSyncedOptionCard({
    required String text,
    required bool isSelected,
    required bool isOptionE,
    required VoidCallback onTap,
  }) {
    // 針對「防猜選項 E」使用灰色調，其餘使用品牌綠
    final activeColor = isOptionE ? Colors.grey.shade600 : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: _syncDuration,
        scale: isSelected ? 1.015 : 1.0,
        curve: _syncCurve,
        child: AnimatedContainer(
          duration: _syncDuration,
          curve: _syncCurve,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.black.withOpacity(0.05),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? activeColor.withOpacity(0.1) : Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: _syncDuration,
                  curve: _syncCurve,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? activeColor : Colors.black87,
                    fontFamily: '微軟正黑體',
                  ),
                  child: Text(text),
                ),
              ),
              AnimatedOpacity(
                duration: _syncDuration,
                curve: _syncCurve,
                opacity: isSelected ? 1.0 : 0.0,
                child: Icon(Icons.check_circle, color: activeColor, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
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

  // 🌟 黃金比例動畫參數
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
    }
  }

  Future<void> _nextQuestion() async {
    if (_selectedAnswerIndex == null) return;

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
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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
        title: const Text('程度測驗', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // 1. 進度條 (使用 const 修飾非動畫部分提升效能)
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

              // 2. 題目區
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 階段標籤
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
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
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '第 ${_currentIndex + 1} 題',
                      style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentQ['question'],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    
                    // 🌟 選項列表：使用 RepaintBoundary 包裹以消除卡頓
                    ...List.generate(displayOptions.length, (index) {
                      return RepaintBoundary( // 🌟 隔離繪製圖層，提升效能
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildSyncedOptionCard(
                            text: displayOptions[index],
                            isSelected: _selectedAnswerIndex == index,
                            isOptionE: (index == 4),
                            onTap: () => setState(() => _selectedAnswerIndex = index),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // 3. 底部行動按鈕
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: AnimatedContainer(
                  duration: _syncDuration,
                  curve: _syncCurve,
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedAnswerIndex != null ? _nextQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: _selectedAnswerIndex != null ? 4 : 0,
                    ),
                    child: Text(
                      _currentIndex == _questions.length - 1 ? '完成測驗' : '下一題',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 已優化效能的選項卡片
  Widget _buildSyncedOptionCard({
    required String text,
    required bool isSelected,
    required bool isOptionE,
    required VoidCallback onTap,
  }) {
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
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.black.withOpacity(0.05),
              width: isSelected ? 2.0 : 1.0,
            ),
            // 🌟 簡化陰影計算，減少 GPU 負擔
            boxShadow: isSelected ? [
              BoxShadow(
                color: activeColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : [],
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
              // 使用 Opacity 穩定佈局
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
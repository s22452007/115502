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
        centerTitle: true,
        title: const Text('程度測驗', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
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
                child: ListView.builder(
                  // 🌟 關鍵修正 1：關閉裁剪，允許內容在放大時稍微超出邊界而不被切斷
                  clipBehavior: Clip.none, 
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayOptions.length,
                  itemBuilder: (context, index) {
                    // 把原本題目區塊放在 ListView 的 Header（這裡簡化處理直接加在 item 裡）
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildContextTag(currentQ['context'] ?? ''),
                          const SizedBox(height: 20),
                          _buildQuestionHeader(),
                          const SizedBox(height: 12),
                          _buildQuestionText(currentQ['question']),
                          const SizedBox(height: 32),
                          _buildOptionItem(index, displayOptions[index]),
                        ],
                      );
                    }
                    return _buildOptionItem(index, displayOptions[index]);
                  },
                ),
              ),

              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 輔助 UI 元件 ---

  Widget _buildContextTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildQuestionHeader() {
    return Text(
      '第 ${_currentIndex + 1} 題',
      style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildQuestionText(String question) {
    return Text(
      question,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.4, fontFamily: '微軟正黑體'),
    );
  }

  Widget _buildOptionItem(int index, String text) {
    return Padding(
      // 🌟 關鍵修正 2：增加外邊距 (Margin)，讓卡片放大時有空間，不影響上下卡片
      padding: const EdgeInsets.symmetric(vertical: 8), 
      child: _buildExactSameCard(
        index: index,
        text: text,
        isSelected: _selectedAnswerIndex == index,
        isOptionE: (index == 4),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: '微軟正黑體'),
          ),
        ),
      ),
    );
  }

  Widget _buildExactSameCard({
    required int index,
    required String text,
    required bool isSelected,
    required bool isOptionE,
  }) {
    final activeColor = isOptionE ? Colors.grey.shade600 : AppColors.primary;

    return GestureDetector(
      onTap: () => setState(() => _selectedAnswerIndex = index),
      child: AnimatedScale(
        duration: _syncDuration,
        scale: isSelected ? 1.015 : 1.0,
        curve: _syncCurve,
        child: AnimatedContainer(
          duration: _syncDuration,
          curve: _syncCurve,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? activeColor : Colors.black.withOpacity(0.08),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? activeColor.withOpacity(0.12) : Colors.black.withOpacity(0.02),
                blurRadius: isSelected ? 12 : 8,
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
                child: Icon(Icons.check_circle, color: activeColor, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
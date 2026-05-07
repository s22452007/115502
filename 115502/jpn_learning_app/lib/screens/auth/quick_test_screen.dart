import 'dart:ui'; // 🌟 必備：用於毛玻璃效果 (ImageFilter)
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
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final currentQ = _questions[_currentIndex];
    final List<String> displayOptions = List<String>.from(currentQ['options']);
    displayOptions.add('E. 我還沒學過這個');

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true, // 🌟 讓內容延伸到 AppBar 後方以實現毛玻璃一體感
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        centerTitle: true,
        title: const Text('程度測驗', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Stack( // 🌟 使用 Stack 實現固定層級
        children: [
          // 1. 底層：可滾動內容
          SafeArea(
            child: ListView.builder(
              clipBehavior: Clip.none, 
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 32, right: 32, top: 40, bottom: 100), // 🌟 頂部預留空間給固定進度條
              itemCount: displayOptions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildContextTag(currentQ['context'] ?? ''),
                      const SizedBox(height: 20),
                      Text('第 ${_currentIndex + 1} 題', style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(currentQ['question'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.4, fontFamily: '微軟正黑體')),
                      const SizedBox(height: 32),
                    ],
                  );
                }
                final optionIndex = index - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildExactSameCard(
                    index: optionIndex,
                    text: displayOptions[optionIndex],
                    isSelected: _selectedAnswerIndex == optionIndex,
                    isOptionE: (optionIndex == 4),
                  ),
                );
              },
            ),
          ),

          // 2. 頂層：毛玻璃固定進度條
          Positioned(
            top: MediaQuery.of(context).padding.top + 56, // 🌟 避開狀態欄與 AppBar 高度
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 🌟 毛玻璃模糊強度
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  color: AppColors.background.withOpacity(0.7), // 🌟 半透明背景
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _questions.length,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200.withOpacity(0.5),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. 底部按鈕
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFixedBottomButton(),
          ),
        ],
      ),
    );
  }

  // --- UI 組件 ---

  Widget _buildContextTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFixedBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background.withOpacity(0), AppColors.background],
        ),
      ),
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

  Widget _buildExactSameCard({required int index, required String text, required bool isSelected, required bool isOptionE}) {
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
            border: Border.all(color: isSelected ? activeColor : Colors.black.withOpacity(0.08), width: isSelected ? 2.0 : 1.0),
            boxShadow: [BoxShadow(color: isSelected ? activeColor.withOpacity(0.12) : Colors.black.withOpacity(0.02), blurRadius: isSelected ? 12 : 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: _syncDuration,
                  curve: _syncCurve,
                  style: TextStyle(fontSize: 17, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? activeColor : Colors.black87, fontFamily: '微軟正黑體'),
                  child: Text(text),
                ),
              ),
              AnimatedOpacity(duration: _syncDuration, curve: _syncCurve, opacity: isSelected ? 1.0 : 0.0, child: Icon(Icons.check_circle, color: activeColor, size: 26)),
            ],
          ),
        ),
      ),
    );
  }
}
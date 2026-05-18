import 'dart:ui';
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
      body: Stack(
        children: [
          // 1. 底層：固定佈局內容 (移除滾動)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 28, 
                right: 28, 
                top: 85, // 調整頂部間距以配合固定 Header
                bottom: 100, // 預留空間給底部按鈕
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 題目資訊與階段標籤 ---
                  _buildContextTag(currentQ['context'] ?? ''),
                  const SizedBox(height: 12),
                  Text('第 ${_currentIndex + 1} 題', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // --- 題目本文 (使用 Flexible 避免過長文字擠壓選項) ---
                  Flexible(
                    flex: 2,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        currentQ['question'], 
                        style: const TextStyle(
                          fontSize: 22, // 稍微縮小一點點
                          fontWeight: FontWeight.w900, 
                          color: Colors.black87, 
                          height: 1.3, 
                          fontFamily: '微軟正黑體'
                        )
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // --- 選項列表 (使用 Column 並壓縮間距) ---
                  ...List.generate(displayOptions.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10), // 縮減選項間距 (從 16 降至 10)
                      child: _buildCompactCard(
                        index: index,
                        text: displayOptions[index],
                        isSelected: _selectedAnswerIndex == index,
                        isOptionE: (index == 4),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 2. 頂層：毛玻璃 Header
          _buildGlassHeader(context),

          // 3. 底部按鈕
          Positioned(bottom: 0, left: 0, right: 0, child: _buildFixedBottomButton()),
        ],
      ),
    );
  }

  // --- 壓縮版卡片設計 (與程度選擇頁面視覺同步，但體積更小) ---
  Widget _buildCompactCard({required int index, required String text, required bool isSelected, required bool isOptionE}) {
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), // 垂直內邊距從 22 降至 14
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18), // 圓角稍微收緊一點點
            border: Border.all(color: isSelected ? activeColor : Colors.black.withOpacity(0.06), width: isSelected ? 2.0 : 1.0),
            boxShadow: [
              if (isSelected) BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: _syncDuration,
                  curve: _syncCurve,
                  style: TextStyle(
                    fontSize: 16, // 從 17 降至 16，確保單行容納更多字
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                    color: isSelected ? activeColor : Colors.black87, 
                    fontFamily: '微軟正黑體'
                  ),
                  child: Text(text),
                ),
              ),
              AnimatedOpacity(duration: _syncDuration, curve: _syncCurve, opacity: isSelected ? 1.0 : 0.0, child: Icon(Icons.check_circle, color: activeColor, size: 22)),
            ],
          ),
        ),
      ),
    );
  }

  // --- 其餘固定元件 (保持 Commit 21 風格) ---

  Widget _buildGlassHeader(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: AppColors.background.withOpacity(0.8),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 50, // 稍微收窄 AppBar 高度
                  child: NavigationToolbar(
                    leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87), onPressed: () => Navigator.pop(context)),
                    centerMiddle: true,
                    middle: const Text('程度測驗', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _questions.length,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200.withOpacity(0.5),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFixedBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.background.withOpacity(0), AppColors.background],
        ),
      ),
      child: AnimatedContainer(
        duration: _syncDuration, curve: _syncCurve,
        width: double.infinity, height: 56,
        child: ElevatedButton(
          onPressed: _selectedAnswerIndex != null ? _nextQuestion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: _selectedAnswerIndex != null ? 3 : 0,
          ),
          child: Text(_currentIndex == _questions.length - 1 ? '完成測驗' : '下一題', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
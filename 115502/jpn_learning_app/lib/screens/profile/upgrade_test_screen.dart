import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/helpers.dart';
import 'package:jpn_learning_app/utils/badge_utils.dart';
import 'package:jpn_learning_app/widgets/dialogs/level_up_dialog.dart';

/// 升級測驗：挑戰「比目前程度高一級」的題目。
/// 答對率達門檻就升級，否則維持原等級（不會降級）。
/// 版面沿用新手程度測驗（QuickTestScreen）的樣式。
class UpgradeTestScreen extends StatefulWidget {
  const UpgradeTestScreen({Key? key}) : super(key: key);

  @override
  State<UpgradeTestScreen> createState() => _UpgradeTestScreenState();
}

class _UpgradeTestScreenState extends State<UpgradeTestScreen> {
  int _currentIndex = 0;
  int? _selectedAnswerIndex;
  List<dynamic> _questions = [];
  final List<bool> _results = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  String _targetLevel = '';
  int _passCount = 0;

  static const _syncDuration = Duration(milliseconds: 280);
  static const _syncCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _loadError = '請先登入才能挑戰升級測驗';
      });
      return;
    }

    final res = await ApiClient.fetchUpgradeQuestions(userId);
    if (!mounted) return;

    final status = (res['_status'] as num?)?.toInt() ?? 0;
    if (status != 200) {
      setState(() {
        _isLoading = false;
        _loadError = res['error']?.toString() ?? '無法載入題目，請稍後再試';
      });
      return;
    }

    setState(() {
      _questions = res['questions'] ?? [];
      _targetLevel = res['target_level']?.toString() ?? '';
      _passCount = (res['pass_count'] as num?)?.toInt() ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _nextQuestion() async {
    if (_selectedAnswerIndex == null) return;

    final isCorrect =
        _selectedAnswerIndex == _questions[_currentIndex]['correctIndex'];
    _results.add(isCorrect);

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
      });
      return;
    }

    // 最後一題 → 送出判定
    setState(() => _isSubmitting = true);
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final res = await ApiClient.submitUpgradeQuiz(userId, _results);
    if (!mounted) return;

    if ((res['_status'] as num?)?.toInt() != 200) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['error']?.toString() ?? '送出失敗，請稍後再試'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final passed = res['passed'] == true;
    final newLevel = res['level']?.toString() ?? '';
    if (passed) {
      context.read<UserProvider>().setJapaneseLevel(newLevel);
    }
    _showResultDialog(
      passed: passed,
      correct: (res['correct'] as num?)?.toInt() ?? 0,
      total: (res['total'] as num?)?.toInt() ?? _results.length,
      passCount: (res['pass_count'] as num?)?.toInt() ?? _passCount,
      level: newLevel,
    );
  }

  void _showResultDialog({
    required bool passed,
    required int correct,
    required int total,
    required int passCount,
    required String level,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.emoji_events_rounded : Icons.sentiment_satisfied_rounded,
              size: 64,
              color: passed ? Colors.amber.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '升級成功！' : '再接再厲！',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '答對 $correct / $total 題（通過需 $passCount 題）',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                border: Border.all(color: AppColors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                passed
                    ? '稱號已晉升為「${AppHelpers.getLevelTitle(level)}」'
                    : '維持「${AppHelpers.getLevelTitle(level)}」稱號',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            if (!passed) ...[
              const SizedBox(height: 12),
              const Text(
                '程度不會下降，隨時可以再來挑戰！',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // 關閉成績對話框

              // 升級成功 → 接著噴出「程度認證」徽章升級慶祝彈窗
              if (passed && mounted) {
                final badgeLevel = BadgeUtils.japaneseLevelToNumber(level);
                await LevelUpDialog.show(
                  context,
                  badgeId: 'level_01',
                  level: badgeLevel,
                  descriptionOverride:
                      '你通過了挑戰，實力獲得認證！新的稱號是「${AppHelpers.getLevelTitle(level)}」。',
                  buttonTextOverride: '太棒了',
                );
              }

              if (mounted) Navigator.pop(context); // 回到個人頁
            },
            child: const Text(
              '完成',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 載入失敗（例如已是 N1、題庫不足）→ 顯示說明頁
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('升級測驗',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 72, color: Colors.amber.shade600),
                const SizedBox(height: 20),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading || _isSubmitting || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // 升級測驗是「證明自己夠格」的挑戰，不提供「我還沒學過」選項
    //（該選項等同答錯，留著只會讓誠實作答比亂猜更吃虧）
    final currentQ = _questions[_currentIndex];
    final displayOptions = List<String>.from(currentQ['options']);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 28, right: 28, top: 85, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContextTag(currentQ['context'] ?? ''),
                  const SizedBox(height: 12),
                  Text(
                    '第 ${_currentIndex + 1} 題 / 共 ${_questions.length} 題',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    flex: 2,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        currentQ['question'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1.3,
                          fontFamily: '微軟正黑體',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(displayOptions.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCompactCard(
                        index: index,
                        text: displayOptions[index],
                        isSelected: _selectedAnswerIndex == index,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          _buildGlassHeader(context),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildFixedBottomButton()),
        ],
      ),
    );
  }

  Widget _buildCompactCard({
    required int index,
    required String text,
    required bool isSelected,
  }) {
    const activeColor = AppColors.primary;
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? activeColor : Colors.black.withOpacity(0.06),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: activeColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: _syncDuration,
                  curve: _syncCurve,
                  style: TextStyle(
                    fontSize: 16,
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
                child: Icon(Icons.check_circle, color: activeColor, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
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
                  height: 50,
                  child: NavigationToolbar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 18, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    centerMiddle: true,
                    middle: Text(
                      _targetLevel.isEmpty
                          ? '升級測驗'
                          : '挑戰「${AppHelpers.getLevelTitle(_targetLevel)}」',
                      style: const TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFixedBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 30),
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
        height: 56,
        child: ElevatedButton(
          onPressed: _selectedAnswerIndex != null ? _nextQuestion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: _selectedAnswerIndex != null ? 3 : 0,
          ),
          child: Text(
            _currentIndex == _questions.length - 1 ? '完成測驗' : '下一題',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart'; // 引入 ApiClient

class TutorAnswerScreen extends StatefulWidget {
  final String question; // 1. 接收上一頁傳來的問題

  const TutorAnswerScreen({Key? key, required this.question}) : super(key: key);

  @override
  State<TutorAnswerScreen> createState() => _TutorAnswerScreenState();
}

class _TutorAnswerScreenState extends State<TutorAnswerScreen> {
  bool _isLoading = true;
  String _answer = '';

  @override
  void initState() {
    super.initState();
    _fetchAnswer(); // 畫面初始化時呼叫 API
  }

  Future<void> _fetchAnswer() async {
    setState(() {
      _isLoading = true;
    });

    // 2. 呼叫 ApiClient
    final result = await ApiClient.askTutorQuestion(widget.question);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.containsKey('answer')) {
        // 假設後端回傳的 key 是 'answer'
        _answer = result['answer'];
      } else if (result.containsKey('error')) {
        _answer = '抱歉，發生錯誤：${result['error']}';
      } else {
        _answer = '抱歉，無法取得解答。';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q: ${widget.question}', // 顯示使用者的問題
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLighter,
                  child: Text('👩', style: TextStyle(fontSize: 22)),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pinyu Shi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Certified Tutor',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. 顯示 Loading 或 答案
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : Text(
                      'A: $_answer',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // 語音播放 (先保留 UI)
            if (!_isLoading) // 載入完畢才顯示語音按鈕
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryLighter),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLighter,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // 返回上一頁繼續問
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '再問一題',
                      style: TextStyle(color: AppColors.primary, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 可以導回首頁或指定頁面
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '結束',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';
// import 'package:jpn_learning_app/utils/constants.dart'; // 如果沒用到可以先註解掉

class RolePlayIntroScreen extends StatefulWidget {
  final String topicTitle; // 🌟 用來接收上一頁傳來的主題

  const RolePlayIntroScreen({
    Key? key,
    required this.topicTitle, // 規定進來一定要帶這個參數
  }) : super(key: key);

  @override
  State<RolePlayIntroScreen> createState() => _RolePlayIntroScreenState();
}

class _RolePlayIntroScreenState extends State<RolePlayIntroScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.78);
  final Color _darkGreen = const Color(0xFF4A7A4D);

  // 🌟 新增的「情境小資料庫」(模擬未來 AI)
  Map<String, dynamic> _getTopicData() {
    String topic = widget.topicTitle;

    if (topic.contains('拉麵')) {
      return {
        'image':
            'https://images.unsplash.com/photo-1552611052-33e04de081de?q=80&w=800&auto=format&fit=crop',
        'vocabs': [
          {
            'kana': 'ラーメン',
            'word': '拉麵',
            'meaning': '拉麵',
            'ex_jp': 'ラーメンを一つください。',
            'ex_en': 'One ramen, please.',
          },
          {
            'kana': 'おかいけい',
            'word': 'お会計',
            'meaning': '結帳',
            'ex_jp': 'お会計をお願いします。',
            'ex_en': 'Can I have the bill please?',
          },
        ],
      };
    } else if (topic.contains('遊戲')) {
      return {
        'image':
            'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=800&auto=format&fit=crop',
        'vocabs': [
          {
            'kana': 'コントローラー',
            'word': '手把',
            'meaning': '遊戲手把',
            'ex_jp': 'コントローラーが壊れました。',
            'ex_en': 'The controller is broken.',
          },
          {
            'kana': 'クリア',
            'word': '破關',
            'meaning': '遊戲通關',
            'ex_jp': 'やっとゲームをクリアした！',
            'ex_en': 'Finally cleared the game!',
          },
        ],
      };
    }
    return {
      'image':
          'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?q=80&w=800&auto=format&fit=crop',
      'vocabs': [
        {
          'kana': 'おすすめ',
          'word': 'お勧め',
          'meaning': '推薦',
          'ex_jp': 'おすすめは何ですか？',
          'ex_en': 'What do you recommend?',
        },
        {
          'kana': 'おかんじょう',
          'word': 'お勘定',
          'meaning': '結帳',
          'ex_jp': 'お勘定をお願いします。',
          'ex_en': 'Can I have the bill please?',
        },
      ],
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 在這裡呼叫函數，抓取對應的資料
    final topicData = _getTopicData();
    final String currentImage = topicData['image'];
    final List<Map<String, String>> currentVocabs =
        List<Map<String, String>>.from(topicData['vocabs']);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 最底層：動態照片
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Image.network(
              currentImage,
              fit: BoxFit.cover,
            ), // 🌟 換成 currentImage
          ),

          // 2. 左上角：返回按鈕
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. 前景層
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFBFE1C3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // 把手
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🌟 顯示從上一頁傳來的主題名稱
                  Text(
                    widget.topicTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _darkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 中間的白色單字卡
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: currentVocabs.length, // 🌟 根據單字數量決定有幾張卡
                      itemBuilder: (context, index) {
                        return _buildVocabCard(
                          currentVocabs[index],
                        ); // 🌟 傳資料給模具
                      },
                    ),
                  ),

                  // 底部按鈕
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 40,
                      top: 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          // 🌟 按下後繼續傳遞標題給聊天室
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RoleplayScreen(topicTitle: widget.topicTitle),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _darkGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Start Role-Play',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 將模具收進類別裡面，並讓它接收資料
  Widget _buildVocabCard(Map<String, String> vocab) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              vocab['kana']!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              vocab['word']!,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vocab['meaning']!,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 20),
            const Text(
              'すみません、',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text(
              'Excuse me,',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              vocab['ex_jp']!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              vocab['ex_en']!,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
} // ⬅️ 這是 _RolePlayIntroScreenState 類別結束的大括號

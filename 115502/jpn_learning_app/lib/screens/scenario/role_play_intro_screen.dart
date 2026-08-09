import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

class RolePlayIntroScreen extends StatefulWidget {
  final String topicTitle;
  final String characterName;

  const RolePlayIntroScreen({
    Key? key,
    required this.topicTitle,
    required this.characterName,
  }) : super(key: key);

  @override
  State<RolePlayIntroScreen> createState() => _RolePlayIntroScreenState();
}

class _RolePlayIntroScreenState extends State<RolePlayIntroScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.78);
  final Color _darkGreen = const Color(0xFF4A7A4D);
  final FlutterTts _flutterTts = FlutterTts();

  // 1 預設 + 2 可選角色清單
  final List<Map<String, dynamic>> _characters = [
    {
      'name': '預設老師',
      'role': '親切耐心，標準日語',
      'origin': '東京',
      'age': '28',
      'gender': '女',
      'personality': '溫柔、有耐心、發音標準',
      'special_traits': '專業的日語教師，會糾正文法錯誤',
    },
    {
      'name': '瀨戶 景',
      'role': '隨性慵懶的貓奴貝斯手',
      'origin': '九州',
      'age': '23',
      'gender': '男',
      'personality': '1. 隨性慵懶 2. 對喜歡的事物充滿熱情 3. 說話帶點幽默感',
      'special_traits': '獨立樂團貝斯手、App開發者、重度貓奴',
    },
  ];

  // 預設選中的角色
  String _selectedCharacterName = '預設老師';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ja-JP");
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("ja-JP");
    await _flutterTts.speak(text);
  }

  // 模擬的情境假資料
  Map<String, dynamic> _getTopicData() {
    String topic = widget.topicTitle;

    if (topic.contains('拉麵')) {
      return {
        'image': 'https://images.unsplash.com/photo-1552611052-33e04de081de?q=80&w=800&auto=format&fit=crop',
        'vocabs': [
          {'kana': 'ラーメン', 'word': '拉麵', 'meaning': '拉麵', 'ex_jp': 'ラーメンを一つください。', 'ex_en': 'One ramen, please.'},
          {'kana': 'おかいけい', 'word': 'お会計', 'meaning': '結帳', 'ex_jp': 'お会計をお願いします。', 'ex_en': 'Can I have the bill please?'},
        ],
      };
    } else if (topic.contains('遊戲')) {
      return {
        'image': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=800&auto=format&fit=crop',
        'vocabs': [
          {'kana': 'コントローラー', 'word': '手把', 'meaning': '遊戲手把', 'ex_jp': 'コントローラーが壊れました。', 'ex_en': 'The controller is broken.'},
          {'kana': 'クリア', 'word': '破關', 'meaning': '遊戲通關', 'ex_jp': 'やっとゲームをクリアした！', 'ex_en': 'Finally cleared the game!'},
        ],
      };
    }
    return {
      'image': 'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?q=80&w=800&auto=format&fit=crop',
      'vocabs': [
        {'kana': 'おすすめ', 'word': 'お勧め', 'meaning': '推薦', 'ex_jp': 'おすすめは何ですか？', 'ex_en': 'What do you recommend?'},
        {'kana': 'おかんじょう', 'word': 'お勘定', 'meaning': '結帳', 'ex_jp': 'お勘定をお願いします。', 'ex_en': 'Can I have the bill please?'},
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
    final topicData = _getTopicData();
    final String currentImage = topicData['image'];
    final List<Map<String, String>> currentVocabs = List<Map<String, String>>.from(topicData['vocabs']);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 背景圖片
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Image.network(
              currentImage,
              fit: BoxFit.cover,
            ),
          ),

          // 2. 返回按鈕
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. 底部白色互動區塊
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.68,
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
                  // 把手裝飾
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 情境標題
                  Text(
                    widget.topicTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _darkGreen,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 單字卡 PageView
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: currentVocabs.length,
                      itemBuilder: (context, index) {
                        return _buildVocabCard(currentVocabs[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 角色選擇區塊標題
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '選擇對話對象',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _darkGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 角色選擇與新增清單 (ListView)
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _characters.length + 1, // +1 是為了放新增按鈕
                      itemBuilder: (context, index) {
                        // 如果是最後一個項目，顯示「新增角色」按鈕
                        if (index == _characters.length) {
                          return GestureDetector(
                            onTap: () => _showAddCharacterDialog(context),
                            child: _buildCharacterButton(
                              isSelected: false,
                              label: '自訂角色',
                              subtitle: '',
                              icon: Icons.add,
                            ),
                          );
                        }

                        // 正常的角色卡片
                        final char = _characters[index];
                        final isSelected = _selectedCharacterName == char['name'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCharacterName = char['name'];
                            });
                          },
                          child: _buildCharacterButton(
                            isSelected: isSelected,
                            label: char['name'],
                            subtitle: char['role'],
                          ),
                        );
                      },
                    ),
                  ),

                  // 底部開始對話按鈕
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40, top: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          // 跳轉至聊天室，並將角色名稱傳過去
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoleplayScreen(
                                topicTitle: widget.topicTitle,
                                characterName: _selectedCharacterName,
                              ),
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
                          '開始對話',
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

  Widget _buildCharacterButton({
    required bool isSelected,
    required String label,
    required String subtitle,
    IconData? icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 132,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? _darkGreen : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _darkGreen, width: 1.5),
        boxShadow: isSelected
            ? [BoxShadow(color: _darkGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
            : [],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: isSelected ? Colors.white : _darkGreen, size: 16),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _darkGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white70 : Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 單字卡 UI 模組
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
              style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  vocab['word']!,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _darkGreen),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: _darkGreen),
                  onPressed: () => _speak(vocab['kana']!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              vocab['meaning']!,
              style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 20),
            const Text(
              'すみません、',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Text(
              'Excuse me,',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  vocab['ex_jp']!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: _darkGreen, size: 20),
                  onPressed: () => _speak(vocab['ex_jp']!),
                ),
              ],
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

  // 新增角色的彈出視窗
  void _showAddCharacterDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final originCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final genderCtrl = TextEditingController();
    final personalityCtrl = TextEditingController();
    final traitsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('新增對話角色', style: TextStyle(color: _darkGreen, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl, 
                  decoration: InputDecoration(
                    labelText: '姓名 (必填)', 
                    hintText: '例如: 瀨戶 景',
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen)),
                  ),
                  cursorColor: _darkGreen,
                ),
                TextField(
                  controller: originCtrl, 
                  decoration: InputDecoration(
                    labelText: '出身地', 
                    hintText: '例如: 九州',
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen)),
                  ),
                  cursorColor: _darkGreen,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl, 
                        decoration: InputDecoration(
                          labelText: '年紀', 
                          hintText: '23',
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen)),
                        ), 
                        keyboardType: TextInputType.number,
                        cursorColor: _darkGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: genderCtrl, 
                        decoration: InputDecoration(
                          labelText: '性別', 
                          hintText: '男/女',
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen)),
                        ),
                        cursorColor: _darkGreen,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: personalityCtrl, 
                  decoration: InputDecoration(
                    labelText: '個性', 
                    hintText: '例如: 隨性慵懶、幽默',
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen)),
                  ),
                  cursorColor: _darkGreen,
                ),
                TextField(
                  controller: traitsCtrl, 
                  decoration: InputDecoration(
                    labelText: '特殊設定', 
                    hintText: '例如: 樂團貝斯手...',
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _darkGreen)),
                  ),
                  maxLines: 2,
                  cursorColor: _darkGreen,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return; 

                setState(() {
                  _characters.add({
                    'name': nameCtrl.text.trim(),
                    'role': '自訂角色', 
                    'origin': originCtrl.text.trim(),
                    'age': ageCtrl.text.trim(),
                    'gender': genderCtrl.text.trim(),
                    'personality': personalityCtrl.text.trim(),
                    'special_traits': traitsCtrl.text.trim(),
                  });
                  _selectedCharacterName = nameCtrl.text.trim();
                });

                Navigator.pop(context); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('新增並選擇', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
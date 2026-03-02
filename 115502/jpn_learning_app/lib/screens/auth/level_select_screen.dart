import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart'; // 確保路徑正確
// TODO: 記得引入你的 HomeScreen
// import 'package:jpn_learning_app/screens/home/home_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  // 用來記錄目前選擇的等級索引，null 代表尚未選擇
  int? _selectedIndex;

  final List<Map<String, String>> levels = [
    {'title': '超級新手', 'desc': '什麼都不會，就想學日文'},
    {'title': '入門新手', 'desc': '會五十音，能進行非常簡單的自我介紹、問候'},
    {'title': '初級應用(N5、N4)', 'desc': '能理解基本生活對話，在餐廳、超商進行簡單溝通'},
    {'title': '中級對話(N3以上)', 'desc': '能大致聽懂日常日語對話，表達自己的想法'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // AppColors.white
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // --- 上半部：標題與選項 (使用 Expanded + SingleChildScrollView 讓內容過長時可滾動) ---
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        '歡迎加入我們！\n請選擇您目前的日語程度',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // 程度選擇按鈕列表
                      ...List.generate(levels.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _LevelButton(
                            title: levels[index]['title']!,
                            desc: levels[index]['desc']!,
                            isSelected: _selectedIndex == index,
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              // --- 下半部：底部按鈕 (固定在畫面最下方) ---
              const SizedBox(height: 12), // 與上方選項保持一點距離
              
              // 我不確定，進行測驗
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuickTestScreen()),
                  );
                },
                child: const Text(
                  '我不確定，進行測驗', 
                  style: TextStyle(
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    color: Colors.grey, // AppColors.textGrey
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 確定並開始學習
              ElevatedButton(
                onPressed: () {
                  if (_selectedIndex == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請先選擇一個程度喔！')),
                    );
                    return;
                  }
                  
                  // 1. 取得使用者選取的程度名稱
                  final selectedLevelTitle = levels[_selectedIndex!]['title']!;
                  
                  // 2. 透過 Provider 將等級儲存起來 (這需要匯入 provider 套件)
                  context.read<UserProvider>().setJapaneseLevel(selectedLevelTitle);
                  
                  // 3. 跳轉到主畫面，並移除前面的選擇畫面堆疊
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // AppColors.primary
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)
                  ),
                ),
                child: const Text(
                  '確定並開始學習', 
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 獨立出來的按鈕元件
class _LevelButton extends StatelessWidget {
  final String title;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelButton({
    required this.title, 
    required this.desc, 
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12), // 讓點擊水波紋符合圓角
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          // 選中時背景變深，未選中時背景較淺
          color: isSelected ? Colors.green.withOpacity(0.8) : Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.black54,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 依照設計圖，文字似乎是置中的
          children: [
            Text(
              title, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                color: isSelected ? Colors.white : Colors.black87
              )
            ),
            const SizedBox(height: 6),
            Text(
              desc, 
              style: TextStyle(
                fontSize: 12, 
                color: isSelected ? Colors.white70 : Colors.black54
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
// 1. Flutter 官方套件
import 'package:flutter/material.dart';

// 2. 第三方套件
import 'package:provider/provider.dart';

// 3. 我們自己寫的工具與狀態管理
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 4. 我們自己寫的畫面 (跳轉用)
import 'package:jpn_learning_app/screens/auth/quick_test_screen.dart'; // 讓「我不確定」按鈕可以跳去測驗
import 'package:jpn_learning_app/screens/home/home_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  // 用來記錄目前選擇的等級索引，null 代表尚未選擇
  int? _selectedIndex;

  final List<Map<String, String>> levels = [
    {'title': '入門新手', 'desc': '會五十音，能進行非常簡單的自我介紹與日常問候'},
    {'title': '初級應用(N5)', 'desc': '能理解基本生活短句，可在餐廳、超商進行簡單的基礎溝通'},
    {'title': '中級應用(N4)', 'desc': '能聽懂放慢的日常會話，可表達自身意圖並與人進行基礎交流'},
    {'title': '高級對話(N3以上)', 'desc': '能大致聽懂自然語速的日常對話，並能順暢表達自己的想法與意見'},
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
                onPressed: () async {
                  // 1. 防呆：檢查有沒有選中任何一個索引
                  if (_selectedIndex == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請先選擇一個程度喔！')),
                    );
                    return;
                  }

                  // 把數字索引轉換回文字標題 (例如：將 1 轉換成 '入門新手')
                  final String selectedTitle = levels[_selectedIndex!]['title']!;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正在儲存您的程度...')),
                  );

                  // 2. 從 Provider 抓出目前登入的 user_id
                  final currentUserId = context.read<UserProvider>().userId;

                  // 3. 如果有登入 (不是訪客)，就存進資料庫
                  if (currentUserId != null) {
                    // 這裡把轉換好的 selectedTitle 傳給後端
                    final result = await ApiClient.updateLevel(currentUserId, selectedTitle);
                    
                    if (!context.mounted) return; // 確保畫面還活著

                    if (result.containsKey('error')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['error'])),
                      );
                      return; // 儲存失敗就中斷
                    }
                  }

                  // 4. 不管是登入還是訪客，都把程度存進 APP 暫存記憶體
                  if (context.mounted) {
                    // 這裡也把 selectedTitle 存進 Provider
                    context.read<UserProvider>().setJapaneseLevel(selectedTitle);
                    
                    // 5. 跳轉到首頁！
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
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

// 獨立出來的按鈕元件 (保持你原本完美的設計)
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
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({Key? key}) : super(key: key);

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  // 控制輸入框文字的 Controller
  final TextEditingController _searchController = TextEditingController();

  // 快速選擇標籤 (加上 Emoji 更生動)
  final List<Map<String, dynamic>> _categories = const [
    {'icon': Icons.ramen_dining, 'text': '一蘭拉麵'},
    {'icon': Icons.sports_esports, 'text': '遊戲日常'},
    {'icon': Icons.menu_book, 'text': '漫畫展'},
    {'icon': Icons.flight_takeoff, 'text': '機場問路'},
    {'icon': Icons.work, 'text': '職場新人'},
    {'icon': Icons.tv, 'text': '動畫巡禮'},
    {'icon': Icons.set_meal, 'text': '迴轉壽司'},
    {'icon': Icons.shopping_bag, 'text': '藥妝店購物'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 提交情境的邏輯
  void _submitScenario() {
    if (_searchController.text.trim().isEmpty) return;

    // 1. 抓取你輸入或點擊的文字 (例如：🎮 遊戲日常)
    String selectedTopic = _searchController.text.trim();

    // 2. 帶著這個文字，直接跳轉到對話頁面 (RoleplayScreen)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleplayScreen(topicTitle: selectedTopic), // 這裡傳遞標題過去
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // 🌟 1. 改為乾淨的白底
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0, // 避免往下滑動時變灰
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '手動建立情境',
          style: TextStyle(
            color: AppColors.primary, // 🌟 2. 標題改為綠字
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        // 點擊空白處收起鍵盤
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '想練習什麼樣的對話呢？',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.textDark, // 使用常數文字顏色
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '輸入您想模擬的情境或主題，AI 將為您量身打造專屬的日語課程！',
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),

              // 輸入框區塊
              TextField(
                controller: _searchController,
                maxLength: 20, // 限制字數
                onChanged: (value) {
                  setState(() {}); // 為了即時更新下方按鈕的狀態
                },
                decoration: InputDecoration(
                  hintText: '例如：在便利商店買咖啡...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '快速選擇主題',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),

              // 標籤區塊
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: _categories.map((category) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // 點擊標籤時，自動填入輸入框
                      setState(() {
                        _searchController.text = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        // 🌟 3. 改用主題色的透明度，質感更柔和
                        color: AppColors.primary.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.primary, // 🌟 4. 統一使用綠字
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // 送出按鈕
              SizedBox(
                width: double.infinity,
                height: 54, // 統一按鈕高度
                child: ElevatedButton(
                  onPressed: _searchController.text.trim().isEmpty
                      ? null // 如果沒有輸入文字，按鈕反灰不可點
                      : _submitScenario, // 呼叫你寫好的跳轉函式
                  style: ElevatedButton.styleFrom(
                    // 🌟 5. 按鈕風格統一為 AppColors.primary
                    backgroundColor: AppColors.primary.withOpacity(0.9),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18), // 統一圓角 18
                    ),
                    elevation: _searchController.text.trim().isEmpty ? 0 : 2,
                  ),
                  child: Text(
                    '開始生成情境',
                    style: TextStyle(
                      color: _searchController.text.trim().isEmpty
                          ? Colors.grey.shade500
                          : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
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
}
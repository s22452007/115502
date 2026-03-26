import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/analyzing_screen.dart';
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
  final List<String> _categories = const [
    '🍜 一蘭拉麵',
    '🎮 遊戲日常',
    '📖 漫畫展',
    '✈️ 機場問路',
    '💼 職場新人',
    '📺 動畫巡禮',
    '🍣 迴轉壽司',
    '🛍️ 藥妝店購物',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 提交情境的邏輯
  void _submitScenario() {
    if (_searchController.text.trim().isEmpty) return;

    // 🌟 1. 抓取你輸入或點擊的文字 (例如：🎮 遊戲日常)
    String selectedTopic = _searchController.text.trim();

    // 🌟 2. 帶著這個文字，直接跳轉到對話頁面 (RoleplayScreen)
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
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // 改為明確的標題
        title: const Text(
          '手動建立情境',
          style: TextStyle(
            color: Colors.white,
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
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '輸入您想模擬的情境或主題，AI 將為您量身打造專屬的日語家教課程！',
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
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
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
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '快速選擇主題',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        // 移除 Emoji 只保留文字 (視你的需求而定，這裡保留全部)
                        _searchController.text = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF6AA86B,
                        ).withOpacity(0.1), // 柔和的綠色背景
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6AA86B).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Color(0xFF4A7C59), // 深綠色文字
                          fontWeight: FontWeight.w600,
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
                child: ElevatedButton(
                  // 🌟 關鍵在這裡！設定 onPressed 按下去要做什麼
                  onPressed: _searchController.text.trim().isEmpty
                      ? null // 如果沒有輸入文字，按鈕反灰不可點
                      : () {
                          // 1. 抓取你輸入的文字 (例如：一蘭拉麵)
                          String selectedTopic = _searchController.text.trim();

                          // 2. 帶著這個主題，跳轉到你的聊天畫面 (RoleplayScreen)！
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RoleplayScreen(topicTitle: selectedTopic),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6AA86B), // 使用主題綠色
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: _searchController.text.trim().isEmpty ? 0 : 2,
                  ),
                  child: Text(
                    '開始生成情境',
                    style: TextStyle(
                      color: _searchController.text.trim().isEmpty
                          ? Colors.grey.shade500
                          : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

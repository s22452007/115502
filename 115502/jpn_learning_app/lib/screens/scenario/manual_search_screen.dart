import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({Key? key}) : super(key: key);

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 🌟 1. 將單純的字串改為包含 IconData 與文字的 Map 陣列
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

  void _submitScenario() {
    if (_searchController.text.trim().isEmpty) return;

    String selectedTopic = _searchController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleplayScreen(topicTitle: selectedTopic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '手動建立情境',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
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
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '輸入您想模擬的情境或主題，AI 將為您量身打造專屬的日語課程！',
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _searchController,
                maxLength: 20,
                onChanged: (value) {
                  setState(() {});
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

              // 🌟 2. 修改標籤區塊，渲染 Icon + Text
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: _categories.map((category) {
                  // 取出圖示跟文字
                  final IconData iconData = category['icon'];
                  final String text = category['text'];

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _searchController.text = text; // 點擊時只填入文字
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, // 左右 Padding 稍微縮小一點配合 Icon
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // 🌟 讓 Row 寬度貼合內容
                        children: [
                          Icon(
                            iconData, 
                            size: 16, // 圖示大小
                            color: AppColors.primary, // 統一綠色
                          ),
                          const SizedBox(width: 6), // 圖示跟文字的間距
                          Text(
                            text,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54, 
                child: ElevatedButton(
                  onPressed: _searchController.text.trim().isEmpty
                      ? null 
                      : _submitScenario, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.9),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18), 
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
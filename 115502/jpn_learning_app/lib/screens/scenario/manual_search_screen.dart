import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/screens/scenario/role_play_intro_screen.dart';


class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({Key? key}) : super(key: key);

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _scenes = [];

  // 角色清單資料
  final List<Map<String, dynamic>> _characters = [
    { 
      'name': '預設老師',
      'role': '親切耐心，標準日語',
      'origin': '東京',
      'age': '30',
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
    _loadScenes();
  }

  Future<void> _loadScenes() async {
    final scenes = await ApiClient.getScenes(quickSelect: true);
    if (!mounted) return;
    setState(() => _scenes = scenes);
  }

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
        builder: (_) => RolePlayIntroScreen(
          topicTitle: selectedTopic,
          characterName: _selectedCharacterName, 
        ),
      ),
    );
  }

  // 👉 新增：直接寫在檔案裡的「新增角色彈窗」函數
  Future<void> _showAddCharacterDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final originCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final genderCtrl = TextEditingController();
    final personalityCtrl = TextEditingController();
    final traitsCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('新增對話角色', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '姓名 (必填)', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
                  cursorColor: AppColors.primary,
                ),
                TextField(
                  controller: originCtrl,
                  decoration: const InputDecoration(labelText: '出身地', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
                  cursorColor: AppColors.primary,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        decoration: const InputDecoration(labelText: '年紀', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
                        keyboardType: TextInputType.number,
                        cursorColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: genderCtrl,
                        decoration: const InputDecoration(labelText: '性別', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
                        cursorColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: personalityCtrl,
                  decoration: const InputDecoration(labelText: '個性', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
                  cursorColor: AppColors.primary,
                ),
                TextField(
                  controller: traitsCtrl,
                  decoration: const InputDecoration(labelText: '特殊設定', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
                  maxLines: 2,
                  cursorColor: AppColors.primary,
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

                // 儲存資料並更新畫面
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

                Navigator.pop(context); // 關閉彈窗
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('新增並選擇', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPageTemplate(
      title: '手動建立情境',
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                        onChanged: (value) => setState(() {}),
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

                      Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: _scenes.map((scene) {
                          final int? codepoint = scene['icon_codepoint'] as int?;
                          final String text = scene['name'] as String;

                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _searchController.text = text;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    codepoint != null
                                        ? IconData(codepoint, fontFamily: 'MaterialIcons')
                                        : Icons.category,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
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
                      
                      const SizedBox(height: 32),

                      const Text(
                        '選擇對話對象',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(right: 16), 
                          scrollDirection: Axis.horizontal,
                          itemCount: _characters.length + 1,
                          itemBuilder: (context, index) {
                            
                            // 渲染新增按鈕
                            if (index == _characters.length) {
                              return GestureDetector(
                                onTap: () => _showAddCharacterDialog(context), // 呼叫本檔案內的函數
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.add, color: AppColors.primary, size: 18),
                                      SizedBox(width: 4),
                                      Text('自訂角色', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // 渲染一般角色卡片
                            final char = _characters[index];
                            final isSelected = _selectedCharacterName == char['name'];

                            return GestureDetector(
                              onTap: () => setState(() => _selectedCharacterName = char['name']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary, width: 1.5),
                                  boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha:0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(char['name'], style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(char['role'], style: TextStyle(color: isSelected ? Colors.white70 : Colors.black54, fontSize: 10)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _searchController.text.trim().isEmpty ? null : _submitScenario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.9),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: _searchController.text.trim().isEmpty ? 0 : 2,
                  ),
                  child: Text(
                    '開始生成情境',
                    style: TextStyle(
                      color: _searchController.text.trim().isEmpty ? Colors.grey.shade500 : Colors.white,
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
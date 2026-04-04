import 'package:flutter/material.dart';
import 'package:jpn_learning_app/providers/favorites_data.dart';
import 'package:jpn_learning_app/screens/scenario/vocab_detail_v2_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final ScenarioItem scenario; // 🌟 接收完整的相簿資料

  const AlbumDetailScreen({Key? key, required this.scenario}) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final Color figmaPrimaryColor = const Color(0xFF6AA86B);
  final Color figmaBgColor = const Color(0xFFF9F9F9);
  final Color figmaTextColor = const Color(0xFF333333);

  // ✏️ 編輯單字對話框 (🌟 傳入 VocabItem 物件)
  void _showEditPhotoDialog(int index, VocabItem oldVocab) {
    final TextEditingController controller = TextEditingController(
      text: oldVocab.word,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '修改單字',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: figmaPrimaryColor, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // 🌟 正確寫法：建立新的 VocabItem 蓋過去，保留其他翻譯跟例句
                  widget.scenario.vocabularyList[index] = VocabItem(
                    word: controller.text.trim(),
                    kana: oldVocab.kana,
                    meaning: oldVocab.meaning,
                    exampleSentence: oldVocab.exampleSentence,
                  );
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已更新單字！')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: figmaPrimaryColor,
              ),
              child: const Text('儲存', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 🗑️ 刪除照片確認框
  void _showDeletePhotoDialog(int index, String word) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '確認刪除',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text('確定要刪除照片「$word」嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // 🌟 正確寫法：從 scenario 的 vocabularyList 刪除
                  widget.scenario.vocabularyList.removeAt(index);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('照片已刪除')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('刪除', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 新增照片
  void _showAddPhotoDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '新增照片單字',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: figmaPrimaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 40,
                  color: figmaPrimaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '請輸入對應的單字名稱：',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '例如：林檎、車...',
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: figmaPrimaryColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final newWord = controller.text.trim();
                if (newWord.isNotEmpty) {
                  setState(() {
                    // 🌟 正確寫法：新增一個 VocabItem 物件
                    widget.scenario.vocabularyList.add(
                      VocabItem(
                        word: newWord,
                        kana: '尚未建立', // 預設值
                        meaning: '自訂單字', // 預設值
                        exampleSentence: '尚未建立例句', // 預設值
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: figmaPrimaryColor,
              ),
              child: const Text(
                '儲存',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: figmaBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: figmaTextColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        // 🌟 正確寫法：從 scenario 取得 title
        title: Text(
          widget.scenario.title,
          style: TextStyle(
            color: figmaTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPhotoDialog,
        backgroundColor: figmaPrimaryColor,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text(
          '新增照片',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // 🌟 正確寫法：判斷 scenario.vocabularyList 是否為空
      body: widget.scenario.vocabularyList.isEmpty
          ? _buildEmptyState()
          : _buildPhotoGrid(context),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '這個相簿目前是空的',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      // 🌟 正確寫法：取得列表長度
      itemCount: widget.scenario.vocabularyList.length,
      itemBuilder: (context, index) {
        // 🌟 正確寫法：抓出物件，再從物件中抓出單字
        final vocabItem = widget.scenario.vocabularyList[index];
        final word = vocabItem.word;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VocabDetailV2Screen(
                  kanji: word,
                  kana: vocabItem.kana, // 🌟 帶入真實資料
                  meaning: vocabItem.meaning, // 🌟 帶入真實資料
                  example: vocabItem.exampleSentence, // 🌟 帶入真實資料
                  imageUrl: 'https://picsum.photos/seed/$word/800/600',
                ),
              ),
            );
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://picsum.photos/seed/$word/800/600',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: figmaTextColor,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  onSelected: (value) {
                    // 🌟 正確寫法：編輯時傳入整個 vocabItem 物件
                    if (value == 'edit') _showEditPhotoDialog(index, vocabItem);
                    if (value == 'delete') _showDeletePhotoDialog(index, word);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('編輯單字')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('刪除照片', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

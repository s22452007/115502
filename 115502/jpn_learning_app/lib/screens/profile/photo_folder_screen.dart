import 'package:flutter/material.dart';
import 'package:jpn_learning_app_new/utils/constants.dart';
import 'package:jpn_learning_app_new/screens/profile/vocab_detail_screen.dart';

class PhotoFolderScreen extends StatelessWidget {
  const PhotoFolderScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> _folders = const [
    {'label': '街景', 'url': 'https://picsum.photos/200/150?1'},
    {'label': '超市', 'url': 'https://picsum.photos/200/150?2'},
    {'label': '車站', 'url': 'https://picsum.photos/200/150?3'},
    {'label': '拉麵店', 'url': 'https://picsum.photos/200/150?4'},
    {'label': '都市', 'url': 'https://picsum.photos/200/150?5'},
    {'label': '咖啡店', 'url': 'https://picsum.photos/200/150?6'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: const Text('照片收藏夾', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.close, color: AppColors.textDark), onPressed: () => Navigator.pop(context))],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
        itemCount: _folders.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const VocabDetailScreen())),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              Image.network(_folders[i]['url']!, fit: BoxFit.cover),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  color: Colors.black45,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(_folders[i]['label']!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

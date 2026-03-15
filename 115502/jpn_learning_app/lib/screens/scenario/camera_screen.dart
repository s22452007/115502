import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/analyzing_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/screens/scenario/scene_result_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 相機預覽區（模擬）
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://picsum.photos/400/800'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 返回按鈕
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // 中央提示框
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '試著拍看周遭造的任何東西！',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '（Try snapping anything！）',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),
          // 底部控制區
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 🖼️ 1. 左邊的相簿按鈕 (把魔法搬來這裡！)
                  IconButton(
                    icon: const Icon(
                      Icons.photo_library, // 或者你原本用的相簿圖示
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () async {
                      // 🌟 這裡加上了 async！
                      // 1. 召喚相簿挑選器
                      final ImagePicker picker = ImagePicker();
                      final XFile? pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );

                      // 2. 如果使用者有選照片（沒按取消）
                      if (pickedFile != null) {
                        if (!context.mounted) return;

                        // 3. 帶著照片跳轉到結果頁！
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SceneResultScreen(imagePath: pickedFile.path),
                          ),
                        );
                      }
                    },
                  ),

                  // 📷 2. 中間的拍照按鈕 (綠色大圓圈，先讓它回歸單純的按鈕)
                  GestureDetector(
                    onTap: () {
                      // TODO: 未來這裡可以放真正「喀嚓」拍照的邏輯
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),

                  // 🔄 3. 右邊的翻轉鏡頭按鈕 (保留原樣)
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          // 手動搜尋入口
          Positioned(
            top: 48,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

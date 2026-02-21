import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class SceneResultScreen extends StatelessWidget {
  const SceneResultScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 場景圖片
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            width: double.infinity,
            child: Image.network('https://picsum.photos/400/500', fit: BoxFit.cover),
          ),
          Positioned(
            top: 48, left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // 底部資訊卡
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('おんせん', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  const Text('お勘定', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const Text('結帳', style: TextStyle(fontSize: 18, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text('すみません、', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  Text('Excuse me,', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  Text('お勘定をお願いします。', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  Text("Can I have the bill please?", style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleplayScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Start Role-Play', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/scene_result_screen.dart';

// 2-2-2 AI 分析中
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({Key? key}) : super(key: key);
  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SceneResultScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.camera_alt, size: 80, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('Ai is analyzing object....', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          CircularProgressIndicator(color: AppColors.primary),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error getting cameras: $e');
  }

  runApp(
    // 保留 MultiProvider，讓整個 APP 都能使用狀態管理
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      // 將子元件改回你原本命名的 JpnLearningApp
      child: const JpnLearningApp(),
    ),
  );
}

class JpnLearningApp extends StatelessWidget {
  const JpnLearningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snap to Learn',
      debugShowCheckedModeBanner: false, // 隱藏右上角的 Debug 標籤
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart'; // 🌟 加上這行

import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/providers/font_size_provider.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'firebase_options.dart'; //不一定要使用

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 先初始化 Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.init();

  // 再初始化相機，不一定要使用
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error getting cameras: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FontSizeProvider()..load()),
      ],
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      builder: (context, child) {
        final isLoggedIn = context.watch<UserProvider>().userId != null;
        final fontScale = isLoggedIn
            ? context.watch<FontSizeProvider>().scale
            : 1.0;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

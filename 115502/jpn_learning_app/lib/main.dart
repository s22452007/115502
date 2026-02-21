import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart';

void main() {
  runApp(const JpnLearningApp());
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
      home: const SplashScreen(),
    );
  }
}

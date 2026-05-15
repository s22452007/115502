import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/home/home_screen.dart';
import 'package:jpn_learning_app/screens/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isVisible = false;
  final Color _flatCanvasColor = const Color(0xFFF4F7F5);
  final Color _brandColor = const Color(0xFF006D3E);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _isVisible = true);
    });
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    
    if (userProvider.isLoggedIn) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _flatCanvasColor,
      body: Center(
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 1000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌟 圖片找不到時自動顯示相機 Icon
              Image.asset(
                'assets/images/logo.png',
                width: 180,
                errorBuilder: (context, error, stackTrace) => 
                  Icon(Icons.camera_alt_rounded, size: 100, color: _brandColor),
              ),
              const SizedBox(height: 24),
              Text(
                "J-LENS",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _brandColor, letterSpacing: 4.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({Key? key}) : super(key: key);

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用與主體一致的背景色
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '文章練習',
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            color: Color(0xFF2C3E50),
          ),
        ),
        centerTitle: true,
        // 設定返回鍵顏色
        iconTheme: const IconThemeData(color: AppColors.primary), 
      ),
      body: const Center(
        child: Text(
          '這裡是文章練習列表，\n我們之後會在這裡實作畫面！',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8E9AAB), 
            fontSize: 16, 
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
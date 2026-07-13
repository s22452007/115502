import 'package:flutter/material.dart';

class SubPageTemplate extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const SubPageTemplate({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 整個頁面設定為白底
      backgroundColor: Colors.white,
      
      // 2. Header (AppBar) 的統一設定
      appBar: AppBar(
        backgroundColor: Colors.white, // Header 白底
        elevation: 0,                  // 移除陰影讓畫面更乾淨平整
        centerTitle: true,             // 標題置中
        
        // 3. 統一所有的圖示（包含返回箭頭）為綠色
        iconTheme: const IconThemeData(
          color: Colors.green, 
        ),
        
        // 4. 統一標題字體為綠色
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: actions,
      ),
      
      // 傳入的畫面主體
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
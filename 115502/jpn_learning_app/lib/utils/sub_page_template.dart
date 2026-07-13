import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart'; // 注意：這裡記得 import 包含 AppColors 與 AppTextStyles 的檔案
// 注意：這裡記得 import 包含 AppColors 與 AppTextStyles 的檔案
// import 'package:你的專案名稱/路徑/theme.dart'; 

class SubPageTemplate extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final bool hideAppBar;

  const SubPageTemplate({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.actions,
    this.hideAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 整個頁面設定為白底
      backgroundColor: AppColors.white, 
      
      appBar: hideAppBar
          ? null
          : AppBar(
              // 2. Header (AppBar) 白底
              backgroundColor: AppColors.white, 
              elevation: 0,                     
              centerTitle: true,                
              
              // 3. 統一圖示（包含返回箭頭）為主綠色
              iconTheme: const IconThemeData(
                color: AppColors.primary, 
              ),

              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios), // 指定你要的 iOS 風格箭頭
                onPressed: () {
                  Navigator.of(context).pop(); // 設定點擊後返回上一頁
                },
              ),
              
              // 4. 標題字體：沿用你的 heading 樣式，並將顏色換成主綠色
              title: Text(
                title,
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.primary,
                ),
              ),
              actions: actions,
            ),
      
      // 傳入的畫面主體
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
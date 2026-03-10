// lib/screens/scenario/result_gallery_screen.dart
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/result_gallery_card.dart';
// 🌟 1. 引入我們剛剛建的資料庫
import 'package:jpn_learning_app/providers/favorites_data.dart';

class ResultGalleryScreen extends StatelessWidget {
  const ResultGalleryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🌟 2. 直接去資料庫拿所有的收藏資料
    final scenarios = FavoritesDataProvider.allFavorites;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '單字探險畫廊',
          style: AppTextStyles.h2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // 🌟 3. 使用 ListView.builder，資料再多也不怕跑不動
      body: scenarios.isEmpty
          ? const Center(child: Text('還沒有收藏任何場景喔！'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scenarios.length,
              itemBuilder: (context, index) {
                // 這裡拿到的就是當前的場景資料
                final scenario = scenarios[index];

                // --- 我用你原本寫好的自訂 Widget ---
                return Padding(
                  padding: const EdgeInsets.bottom(16.0),
                  child: ResultGalleryCard(
                    title: scenario.title,
                    date: scenario.date,
                    // 我們這裡做個小優化：如果沒有圖片，就用一個預設的顏色
                    image: scenario.image != null
                        ? Image.asset(scenario.image!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.primaryLighter,
                            child: const Icon(
                              Icons.ramen_dining,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }
}

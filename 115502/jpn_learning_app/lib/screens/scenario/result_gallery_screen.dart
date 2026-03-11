import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 🌟 已經幫你把會報錯的第 4 行刪掉了！
import 'package:jpn_learning_app/providers/favorites_data.dart';

class ResultGalleryScreen extends StatelessWidget {
  const ResultGalleryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scenarios = FavoritesDataProvider.allFavorites;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '單字探險畫廊',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: scenarios.isEmpty
          ? const Center(child: Text('還沒有收藏任何場景喔！'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scenarios.length,
              itemBuilder: (context, index) {
                final scenario = scenarios[index];

                // 🌟 直接在這裡手刻精美卡片，不再依賴外部檔案！
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: scenario.image != null
                            ? Image.asset(scenario.image!, fit: BoxFit.cover)
                            : const Icon(
                                Icons.ramen_dining,
                                color: AppColors.primary,
                                size: 30,
                              ),
                      ),
                    ),
                    title: Text(
                      scenario.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        scenario.date,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      // 之後這裡也可以連動到你的單字詳細頁面！
                    },
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final VoidCallback onTap;
  final Function(Map<String, dynamic>) onRename;
  final Function(Map<String, dynamic>) onDelete;

  const FolderCard({
    Key? key,
    required this.folder,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  }) : super(key: key);

  // 🌟 智慧圖示判斷：根據資料夾名稱給予對應的 ICON，沒有關聯的就回傳 null (空白)
  IconData? _getIconForFolder(String name, bool isDefault) {
    if (isDefault) return Icons.star_rounded; // 預設相簿給予一顆星星
    
    final lowerName = name.toLowerCase();
    
    // 飲食相關
    if (lowerName.contains('吃') || lowerName.contains('食') || lowerName.contains('餐') || lowerName.contains('喝') || lowerName.contains('food')) {
      return Icons.restaurant_rounded;
    } 
    // 交通相關
    else if (lowerName.contains('車') || lowerName.contains('行') || lowerName.contains('交通') || lowerName.contains('站') || lowerName.contains('traffic')) {
      return Icons.directions_transit_rounded;
    } 
    // 購物相關
    else if (lowerName.contains('買') || lowerName.contains('購') || lowerName.contains('錢') || lowerName.contains('shop')) {
      return Icons.shopping_bag_rounded;
    } 
    // 旅遊相關
    else if (lowerName.contains('玩') || lowerName.contains('遊') || lowerName.contains('旅') || lowerName.contains('景') || lowerName.contains('travel')) {
      return Icons.flight_takeoff_rounded;
    } 
    // 服飾相關
    else if (lowerName.contains('衣') || lowerName.contains('服') || lowerName.contains('穿') || lowerName.contains('clothes')) {
      return Icons.checkroom_rounded;
    } 
    // 居住相關
    else if (lowerName.contains('住') || lowerName.contains('家') || lowerName.contains('屋') || lowerName.contains('宿') || lowerName.contains('home')) {
      return Icons.home_rounded;
    } 
    // 學習相關
    else if (lowerName.contains('學') || lowerName.contains('書') || lowerName.contains('課') || lowerName.contains('考') || lowerName.contains('study')) {
      return Icons.menu_book_rounded;
    } 
    // 醫療相關
    else if (lowerName.contains('病') || lowerName.contains('醫') || lowerName.contains('藥') || lowerName.contains('hospital')) {
      return Icons.local_hospital_rounded;
    } 
    // 如果後端未來有支援傳送自訂 icon 則使用後端的
    else if (folder['icon_codepoint'] != null) {
      return IconData(folder['icon_codepoint'] as int, fontFamily: 'MaterialIcons');
    }
    
    // 沒配對到任何相關詞彙，就直接回傳 null (畫面會留白)
    return null; 
  }

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF2C3E50);
    const Color subColor = Color(0xFF8E9AAB);

    final String folderName = folder['name'] ?? '預設相簿';
    final bool isDefault = folder['is_default'] == true;
    
    // 🌟 修正問題：將 'vocab_count' 修正為後端真實傳遞的 'count'，數字就不會是 0 了
    final int vocabCount = (folder['count'] as num?)?.toInt() ?? 0;
    
    // 取得我們剛剛寫好的智慧 ICON
    final IconData? folderIcon = _getIconForFolder(folderName, isDefault);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🌟 正方形相簿主體
        AspectRatio(
          aspectRatio: 1.0, 
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08), 
                borderRadius: BorderRadius.circular(20), 
              ),
              child: Stack(
                children: [
                  // 置中的圖示：如果有圖示就顯示，沒有 (null) 就顯示空白組件 (SizedBox.shrink)
                  Center(
                    child: folderIcon != null 
                        ? Icon(
                            folderIcon, 
                            color: AppColors.primary,
                            size: 36,
                          )
                        : const SizedBox.shrink(), // 👈 這裡達成了「沒有的話就空白」的需求
                  ),
                  
                  // 右上角的更多操作選單
                  if (!isDefault)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary, size: 18), 
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        onSelected: (val) {
                          if (val == 'rename') onRename(folder);
                          if (val == 'delete') onDelete(folder);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(children: [
                              Icon(Icons.edit_rounded, color: Colors.blue, size: 16),
                              SizedBox(width: 8),
                              Text('編輯名稱', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_rounded, color: Colors.redAccent, size: 16),
                              SizedBox(width: 8),
                              Text('刪除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))
                            ]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        // 🌟 下方的相簿名稱與單字數
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                folderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13, 
                ),
              ),
              const SizedBox(height: 2),
              // 這裡就會顯示真實的總數量了！
              Text(
                '$vocabCount 個單字',
                style: const TextStyle(
                  color: subColor,
                  fontSize: 11, 
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
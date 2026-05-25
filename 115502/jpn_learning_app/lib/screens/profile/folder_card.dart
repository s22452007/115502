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

  // 🌟 升級版：智慧圖示判斷，涵蓋更多你提到的生活單字
  IconData? _getIconForFolder(String name, bool isDefault) {
    if (isDefault) return Icons.star_rounded; 
    
    final lowerName = name.toLowerCase();
    
    // 1. 食物與點心 (草莓, 布丁等)
    if (lowerName.contains('吃') || lowerName.contains('食') || lowerName.contains('餐') || 
        lowerName.contains('草莓') || lowerName.contains('布丁') || lowerName.contains('蛋糕') || 
        lowerName.contains('食物') || lowerName.contains('food')) {
      return Icons.restaurant_menu_rounded;
    }
    // 2. 動物相關 (狗, 魚)
    else if (lowerName.contains('狗') || lowerName.contains('貓') || lowerName.contains('魚') || 
             lowerName.contains('動物') || lowerName.contains('pet')) {
      return Icons.pets_rounded;
    }
    // 3. 交通
    else if (lowerName.contains('車') || lowerName.contains('交通') || lowerName.contains('站')) {
      return Icons.directions_transit_rounded;
    }
    // 4. 購物
    else if (lowerName.contains('買') || lowerName.contains('店') || lowerName.contains('商品')) {
      return Icons.shopping_bag_rounded;
    }
    // 5. 旅遊/風景
    else if (lowerName.contains('旅遊') || lowerName.contains('風景') || lowerName.contains('景點')) {
      return Icons.landscape_rounded;
    }
    // 6. 學習
    else if (lowerName.contains('學習') || lowerName.contains('書') || lowerName.contains('單字')) {
      return Icons.menu_book_rounded;
    }
    
    return null; // 找不到對應 ICON 時回傳 null，呈現空白
  }

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF2C3E50);
    const Color subColor = Color(0xFF8E9AAB);

    final String folderName = folder['name'] ?? '預設相簿';
    final bool isDefault = folder['is_default'] == true;
    
    // 🌟 修正：確保取用真實的計數欄位
    final int vocabCount = (folder['count'] as num?)?.toInt() ?? 0;
    final IconData? folderIcon = _getIconForFolder(folderName, isDefault);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
                  Center(
                    child: folderIcon != null 
                        ? Icon(folderIcon, color: AppColors.primary, size: 36)
                        : const SizedBox.shrink(), // 🌟 沒有相關字詞就保持空白
                  ),
                  
                  if (!isDefault)
                    Positioned(
                      top: 4, right: 4,
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
                style: const TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '$vocabCount 個單字',
                style: const TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
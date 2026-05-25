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

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF2C3E50);
    const Color subColor = Color(0xFF8E9AAB);

    final String folderName = folder['name'] ?? '預設相簿';
    final int vocabCount = (folder['vocab_count'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🌟 正方形相簿主體 (自動適應 3 欄寬度)
        AspectRatio(
          aspectRatio: 1.0, 
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08), 
                borderRadius: BorderRadius.circular(20), // 圓角稍微縮小配合小卡片
              ),
              child: Stack(
                children: [
                  // 置中的大資料夾圖示 (微調縮小配合卡片大小)
                  Center(
                    child: Icon(
                      Icons.folder_copy_rounded, 
                      color: AppColors.primary,
                      size: 36, // 🌟 縮小圖示
                    ),
                  ),
                  
                  // 右上角的更多操作選單
                  if (folder['is_default'] != true)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary, size: 18), // 🌟 縮小選單圖示
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
        
        // 🌟 下方的相簿名稱與單字數 (字體微調)
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
                  fontSize: 13, // 🌟 縮小標題字體以防止超出
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$vocabCount 個單字',
                style: const TextStyle(
                  color: subColor,
                  fontSize: 11, // 🌟 縮小副標字體
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
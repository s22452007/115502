import 'package:flutter/material.dart';

class FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final VoidCallback onTap;
  final void Function(Map<String, dynamic>) onRename;
  final void Function(Map<String, dynamic>) onDelete;

  const FolderCard({
    Key? key,
    required this.folder,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF6AA86B);
    const Color textColor = Color(0xFF333333);
    const Color subColor = Color(0xFF9E9E9E);

    final isDefault = folder['is_default'] == true;
    final count = folder['count'] ?? 0;
    final folderId = folder['id'];

    final colors = [
      const Color(0xFF6AA86B),
      const Color(0xFF6B9BD2),
      const Color(0xFFD28B6B),
      const Color(0xFF8B6B9E),
      const Color(0xFFD2C36B),
    ];
    final color = isDefault ? primaryGreen : colors[(folderId ?? 0) % colors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isDefault ? Icons.auto_awesome_rounded : Icons.folder_rounded,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder['name'] ?? '未命名',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count 個單字',
                    style: const TextStyle(fontSize: 13, color: subColor),
                  ),
                ],
              ),
            ),
            if (!isDefault)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'rename') onRename(folder);
                  if (value == 'delete') onDelete(folder);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('重新命名')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('刪除資料夾', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
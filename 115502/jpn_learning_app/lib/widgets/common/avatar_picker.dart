import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

// 回傳這個值代表使用者選擇從相簿上傳
const kAvatarGallery = '__gallery__';

Future<String?> showAvatarPicker(BuildContext context, {String? currentAvatar}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AvatarPickerSheet(currentAvatar: currentAvatar),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  final String? currentAvatar;
  const _AvatarPickerSheet({this.currentAvatar});

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    // 若目前頭像是 emoji，預選它；否則不預選
    if (widget.currentAvatar != null &&
        kAvatarPresets.containsKey(widget.currentAvatar)) {
      _selected = widget.currentAvatar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emojis = kAvatarPresets.keys.toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖曳條
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '選擇你的頭像',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),

          // 從相簿上傳按鈕
          GestureDetector(
            onTap: () => Navigator.pop(context, kAvatarGallery),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      color: Color(0xFF5C8663), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '從相簿上傳照片',
                    style: TextStyle(
                      color: Color(0xFF5C8663),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 分隔線
          Row(children: [
            Expanded(child: Divider(color: Colors.grey.shade200)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('或選擇可愛頭像',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade200)),
          ]),
          const SizedBox(height: 16),

          // 動物頭像格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1,
            ),
            itemCount: emojis.length,
            itemBuilder: (_, i) {
              final emoji = emojis[i];
              final bg = kAvatarPresets[emoji]!;
              final isSelected = _selected == emoji;

              return GestureDetector(
                onTap: () => setState(() => _selected = emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: const Color(0xFF5C8663), width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: const Color(0xFF5C8663)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8)
                          ]
                        : [],
                  ),
                  child: Container(
                    decoration:
                        BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Center(
                      child:
                          Text(emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // 確認按鈕
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C8663),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: const Text(
                '確認選擇',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/user_avatar.dart';

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
    _selected = widget.currentAvatar;
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
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
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
                        ? [BoxShadow(color: const Color(0xFF5C8663).withValues(alpha: 0.3), blurRadius: 8)]
                        : [],
                  ),
                  child: Container(
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
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
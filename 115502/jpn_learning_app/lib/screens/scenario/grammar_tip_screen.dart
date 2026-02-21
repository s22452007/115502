import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class GrammarTipScreen extends StatelessWidget {
  const GrammarTipScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('語法小教室', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _TabBtn(label: '你的說法', selected: true),
            const SizedBox(width: 8),
            _TabBtn(label: '道地說法', selected: false),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text('✗ください', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.primaryLighter,
                  child: Text('👩', style: TextStyle(fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sensei's Note：", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text(
                      '"Mizu" is general water, but in restaurants and izakayas, \'O-hya\' is the polite and standard term for cold drinking water. Using \'O-hya\' shows better cultural understanding and politeness.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            Chip(label: Text('#Grammar（語法）'), backgroundColor: AppColors.primaryLighter),
            Chip(label: Text('#Vocabulary（詞彙）'), backgroundColor: AppColors.primaryLighter),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('了解！', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  const _TabBtn({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontSize: 13)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/scenario/naturalness_screen.dart';

// 2-2-4 角色扮演
class RoleplayScreen extends StatefulWidget {
  const RoleplayScreen({Key? key}) : super(key: key);
  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'すみません、これをください', 'isUser': true},
    {'text': 'はい、かしこまりました。', 'isUser': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: const Text('Restaurant Scenario', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                return Align(
                  alignment: msg['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!msg['isUser']) ...[
                        CircleAvatar(radius: 16, backgroundColor: AppColors.primaryLighter,
                            child: Icon(Icons.smart_toy, color: AppColors.primary, size: 18)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                        decoration: BoxDecoration(
                          color: msg['isUser'] ? AppColors.primary : AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(msg['text'],
                            style: TextStyle(color: msg['isUser'] ? Colors.white : AppColors.textDark, fontSize: 15)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.mic, color: AppColors.primary), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '輸入日文...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: AppColors.primary),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NaturalnessScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

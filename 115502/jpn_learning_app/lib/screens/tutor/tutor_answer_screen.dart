import 'package:flutter/material.dart';
import 'package:jpn_learning_app_new/utils/constants.dart';

class TutorAnswerScreen extends StatelessWidget {
  const TutorAnswerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Q: 為什麼這裡要用 "WO"？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: AppColors.primaryLighter,
                    child: Text('👩', style: TextStyle(fontSize: 22))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pinyu Shi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(children: [
                    Icon(Icons.verified, color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text('Certified Tutor', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                  ]),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('A: In this context, "wo" marks the object of the verb........',
                  style: TextStyle(fontSize: 14, color: AppColors.textDark)),
            ),
            const SizedBox(height: 16),
            // 語音播放
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryLighter),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle, color: AppColors.primary, size: 32),
                  const SizedBox(width: 8),
                  Expanded(child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLighter]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('再問一題', style: TextStyle(color: AppColors.primary, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('結束', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

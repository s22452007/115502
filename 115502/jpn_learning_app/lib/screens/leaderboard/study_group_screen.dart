import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class StudyGroupScreen extends StatelessWidget {
  const StudyGroupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Icon(Icons.camera_alt, color: Colors.white),
        centerTitle: true,
        actions: [Icon(Icons.person_outline, color: Colors.white), const SizedBox(width: 12)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardYellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('study group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CircleAvatar(radius: 20, backgroundColor: AppColors.primaryLighter,
                          child: Icon(Icons.person, color: AppColors.primary)),
                    )),
                  ),
                  const SizedBox(height: 16),
                  const Text('Shared Goal: 5000 points', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('3000/5000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.85),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Remind Teammates', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

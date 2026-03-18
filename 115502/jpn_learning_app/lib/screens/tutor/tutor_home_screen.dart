import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/bottom_nav_bar.dart';
import 'package:jpn_learning_app/screens/tutor/ask_question_screen.dart';
import 'package:jpn_learning_app/widgets/app_drawer.dart';

class TutorHomeScreen extends StatelessWidget {
  const TutorHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Icon(Icons.camera_alt, color: Colors.white),
        centerTitle: true,
        actions: [Icon(Icons.person_outline, color: Colors.white), const SizedBox(width: 12)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ask a Question 按鈕
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskQuestionScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      child: Icon(Icons.monetization_on, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Ask a Question', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('(50 J-Points)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('My Question History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _QuestionTile(title: 'Izakaya polite form', status: 'Answered', statusColor: AppColors.primary),
            _QuestionTile(title: 'Ramen shop particie usage', status: 'Pending', statusColor: AppColors.textGrey),
            const SizedBox(height: 20),
            const Text('Popular FAQS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _FaqTile(title: 'Difference between'),
            _FaqTile(title: 'when to use Keigo'),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(currentIndex: 4, onTap: (_) {}),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final String title, status;
  final Color statusColor;
  const _QuestionTile({required this.title, required this.status, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(status, style: TextStyle(color: statusColor, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String title;
  const _FaqTile({required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

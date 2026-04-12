import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/profile/badge_library_screen.dart';

class ProfileAchievementsSection extends StatelessWidget {
  final bool isGuest;
  final Function(String) onGuestClick;

  const ProfileAchievementsSection({
    Key? key,
    required this.isGuest,
    required this.onGuestClick,
  }) : super(key: key);

  int _getLevel(BuildContext context, String id) {
    if (isGuest) return 0;
    final badgeProgress = context.read<UserProvider>().badgeProgress;
    final milestones = {
      'level_01': [1, 2, 3, 4, 5],
      'vocab_01': [10, 50, 100, 300, 500],
      'streak_01': [3, 7, 14, 30, 60],
    };
    int progress = badgeProgress[id] ?? 0;
    List<int> ms = milestones[id] ?? [];
    int level = 0;
    for (int i = 0; i < ms.length; i++) {
      if (progress >= ms[i]) level = i + 1;
      else break;
    }
    return level;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFFF1F8E9);
    final textColor = const Color(0xFF333333);
    final primaryGreen = const Color.fromARGB(255, 74, 124, 89);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('成就徽章', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              TextButton(
                onPressed: () {
                  if (isGuest) {
                    onGuestClick('成就徽章庫');
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BadgeLibraryScreen()));
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isGuest ? '登入查看' : '查看全部',
                      style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Icon(Icons.chevron_right, color: primaryGreen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniBadge(Icons.school, '程度認證', _getLevel(context, 'level_01'), textColor),
              _buildMiniBadge(Icons.menu_book, '單字大富翁', _getLevel(context, 'vocab_01'), textColor),
              _buildMiniBadge(Icons.local_fire_department, '學習火種', _getLevel(context, 'streak_01'), textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String title, int level, Color textColor) {
    Map<String, dynamic> theme;
    switch (level) {
      case 5: theme = {'color': Colors.purpleAccent, 'isGradient': true}; break;
      case 4: theme = {'color': Colors.amber[400]!, 'isGradient': false}; break;
      case 3: theme = {'color': Colors.blueGrey[300]!, 'isGradient': false}; break;
      case 2: theme = {'color': Colors.orange[700]!, 'isGradient': false}; break;
      case 1: theme = {'color': Colors.brown[400]!, 'isGradient': false}; break;
      default: theme = {'color': Colors.grey[400]!, 'isGradient': false}; break;
    }

    bool isUnlocked = level > 0;
    bool isGradient = theme['isGradient'];
    Color solidColor = isGradient ? Colors.white : theme['color'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked ? solidColor.withOpacity(0.15) : Colors.grey[200],
            gradient: isGradient ? const SweepGradient(colors: [Colors.purple, Colors.blue, Colors.pink, Colors.purple]) : null,
            border: !isGradient ? Border.all(color: isUnlocked ? solidColor : Colors.transparent, width: 2.5) : null,
          ),
          child: isGradient
              ? Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: Icon(icon, color: Colors.purple, size: 24),
                )
              : Icon(isUnlocked ? icon : Icons.lock, color: isUnlocked ? solidColor : Colors.grey[400], size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: isUnlocked ? textColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
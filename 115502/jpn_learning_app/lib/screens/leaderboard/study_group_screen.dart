import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

import 'invite_group_members_screen.dart';
import 'group_invites_screen.dart';
import 'study_group_home_screen.dart'; // 記得引入大廳畫面

class StudyGroupScreen extends StatefulWidget {
  const StudyGroupScreen({Key? key}) : super(key: key);

  @override
  State<StudyGroupScreen> createState() => _StudyGroupScreenState();
}

class _StudyGroupScreenState extends State<StudyGroupScreen> {
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);
  static const Color lightGreen = Color(0xFFEAF3E3);
  static const Color beige = Color(0xFFF6EBC7);

  bool _isLoading = true;
  Map<String, dynamic>? _groupData;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  // 去後端查「我有沒有加入小組？」
  Future<void> _loadGroupData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final result = await ApiClient.getMyGroup(userId);
    
    if (mounted) {
      setState(() {
        if (result['has_group'] == true) {
          _groupData = result; // 把抓到的公會資料存起來
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. 正在查詢時顯示 Loading
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // 2. 如果查到有群組，直接前往「公會大廳」，並把資料傳過去！
    if (_groupData != null) {
      return StudyGroupHomeScreen(groupData: _groupData!);
    }

    // 3. 如果沒有群組，顯示你原本寫好的空狀態介面
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Icon(Icons.groups, color: Colors.white),
        centerTitle: true,
      ),
      body: _buildEmptyGroupView(context),
    );
  }

  Widget _buildEmptyGroupView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 74,
                  color: AppColors.primaryLighter,
                ),
                const SizedBox(height: 16),
                const Text(
                  '你目前還沒有加入任何學習小組',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '和好友一起累積進度，學習更有動力',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: subText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          
          // 建立小組 / 邀請好友 (這裡我們統一導向邀請頁面)
          _mainButton(
            text: '建立小組並邀請好友',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InviteGroupMembersScreen(),
                ),
              ).then((_) => _loadGroupData()); // 建立完回來時，重新刷新畫面！
            },
          ),
        ],
      ),
    );
  }

  Widget _mainButton({required String text, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
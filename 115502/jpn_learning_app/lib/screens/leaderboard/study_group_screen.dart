import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

import 'invite_group_members_screen.dart';
import 'group_invites_screen.dart';
import 'study_group_home_screen.dart'; 

class StudyGroupScreen extends StatefulWidget {
  final bool showAppBar; // 控制是否顯示頂部導覽列（排行榜嵌入時為 false）

  const StudyGroupScreen({
    Key? key, 
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<StudyGroupScreen> createState() => _StudyGroupScreenState();
}

class _StudyGroupScreenState extends State<StudyGroupScreen> {
  static const Color textDark = Color(0xFF333333);
  static const Color subText = Color(0xFF6E6E6E);

  bool _isLoading = true;
  Map<String, dynamic>? _groupData;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      final result = await ApiClient.getMyGroup(userId);
      if (mounted) {
        setState(() {
          if (result['has_group'] == true) {
            _groupData = result; 
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('讀取群組資料錯誤: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildWrapper(
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // 查到有群組，前往公會大廳，並傳遞 showAppBar 狀態
    if (_groupData != null) {
      return StudyGroupHomeScreen(
        groupData: _groupData!,
        showAppBar: widget.showAppBar,
      );
    }

    // 沒有群組，顯示完善的空狀態介面
    return _buildWrapper(child: _buildEmptyGroupView(context));
  }

  // 包裝器：負責判斷需不需要 Scaffold 和 AppBar
  Widget _buildWrapper({required Widget child}) {
    if (!widget.showAppBar) {
      // 給排行榜用的，不加 Scaffold，背景直接透明或依賴外層
      return child; 
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F2),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('學習小組', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: child,
    );
  }

  Widget _buildEmptyGroupView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                Icon(
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
                  '和好友一起累積 points，學習更有動力',
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
          _mainButton(
            text: '建立小組並邀請好友', 
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteGroupMembersScreen()),
              ).then((_) => _loadGroupData()); // 建立/邀請完畢返回時，重新抓取後端資料
            },
          ),
          
          const SizedBox(height: 22),
          
          // 收到的小組邀請
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '收到的小組邀請',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupInvitesScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EBC7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Text('1', style: TextStyle(color: Color(0xFF4E8B4C), fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('好友學習小組', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                        SizedBox(height: 4),
                        Text('林美伶邀請你加入', style: TextStyle(fontSize: 14, color: subText)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 推薦一起學習的好友
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '推薦一起學習的好友',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLighter,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('佐藤學長', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textDark)),
                      SizedBox(height: 2),
                      Text('@sato_senpai', style: TextStyle(fontSize: 14, color: subText)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3E3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('邀請加入', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
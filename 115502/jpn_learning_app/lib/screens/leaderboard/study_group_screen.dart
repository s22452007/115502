import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

import 'invite_group_members_screen.dart';
import 'group_invites_screen.dart';
import 'study_group_home_screen.dart'; 

class StudyGroupScreen extends StatefulWidget {
  final bool showAppBar; 

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
  List<dynamic> _invites = []; // 用來存放收到的邀請名單

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      // 同時抓取「我的公會」與「我的邀請」
      final groupResult = await ApiClient.getMyGroup(userId);
      final invitesResult = await ApiClient.getGroupInvites(userId);

      if (mounted) {
        setState(() {
          if (groupResult['has_group'] == true) {
            _groupData = groupResult; 
          }
          
          // 如果後端有傳回 invites 陣列，就存起來
          if (invitesResult.containsKey('invites') && invitesResult['invites'] is List) {
            _invites = invitesResult['invites'];
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

    if (_groupData != null) {
      return StudyGroupHomeScreen(
        groupData: _groupData!,
        showAppBar: widget.showAppBar,
      );
    }

    return _buildWrapper(child: _buildEmptyGroupView(context));
  }

  Widget _buildWrapper({required Widget child}) {
    if (!widget.showAppBar) return child; 

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
              ).then((_) => _loadGroupData());
            },
          ),
          
          const SizedBox(height: 22),
          
          // 收到的小組邀請區塊
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '收到的小組邀請',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
            ),
          ),
          const SizedBox(height: 10),
          
          // 這裡根據 _invites 是否為空來決定顯示哪個卡片！
          _invites.isEmpty ? _buildNoInvitesCard() : _buildHasInvitesCard(),

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

  // 沒有邀請時顯示的灰色狀態
  Widget _buildNoInvitesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Text(
          '目前沒有收到任何邀請喔！',
          style: TextStyle(
            fontSize: 15,
            color: subText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // 有邀請時顯示的黃色按鈕，並顯示收到的邀請數量
  Widget _buildHasInvitesCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GroupInvitesScreen()),
        ).then((_) => _loadGroupData()); // 去處理完邀請回來後，刷新畫面
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
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: Text(
                '${_invites.length}', // 顯示真實邀請數量
                style: const TextStyle(color: Color(0xFF4E8B4C), fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('你有待處理的邀請', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                  const SizedBox(height: 4),
                  Text('點擊查看誰邀請了你進入小組', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
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
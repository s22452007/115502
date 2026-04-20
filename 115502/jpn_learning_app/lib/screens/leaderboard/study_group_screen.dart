import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

import 'invite_group_members_screen.dart';
import 'group_invites_screen.dart';
import 'study_group_home_screen.dart'; 
import 'group_config_screen.dart';


import 'package:jpn_learning_app/widgets/study_group/empty_group_banner.dart';
import 'package:jpn_learning_app/widgets/study_group/invites_status_card.dart';

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

  bool _isLoading = true;
  Map<String, dynamic>? _groupData;
  List<dynamic> _invites = []; 

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      final groupResult = await ApiClient.getMyGroup(userId);
      final invitesResult = await ApiClient.getGroupInvites(userId);

      if (mounted) {
        setState(() {
          // 攔截自動結算訊號
          if (groupResult['just_expired'] == true) {
            _groupData = null;

            // 如果有回傳最新的點數，立刻更新錢包！
            if (groupResult.containsKey('new_j_pts')) {
               context.read<UserProvider>().setJPts(groupResult['new_j_pts']);
            }

            Future.delayed(Duration.zero, () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('📜 上週結算通知', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Text(groupResult['message'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('我知道了', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              );
            });
          } else if (groupResult['has_group'] == true) {
            _groupData = groupResult; 
          }
          
          if (invitesResult.containsKey('invites') && invitesResult['invites'] is List) {
            _invites = invitesResult['invites'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
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

    // 狀態 A：已有小組，渲染大魔王畫面
    if (_groupData != null) {
      return StudyGroupHomeScreen(
        groupData: _groupData!,
        showAppBar: widget.showAppBar,
      );
    }

    // 狀態 B：沒有小組，渲染大廳畫面
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

  // 超級乾淨的大廳畫面！
  Widget _buildEmptyGroupView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // 🧱 積木 1：尚未加入小組橫幅
          const EmptyGroupBanner(),
          const SizedBox(height: 18),
          
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupConfigScreen()),
                ).then((_) => _loadGroupData());
              },
              child: const Text(
                '建立小組並邀請好友',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          
          const SizedBox(height: 22),
          
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('收到的小組邀請', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark)),
          ),
          const SizedBox(height: 10),
          
          // 🧱 積木 2：邀請狀態卡片
          InvitesStatusCard(
            invitesCount: _invites.length,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupInvitesScreen()),
              ).then((_) => _loadGroupData());
            },
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/leaderboard/study_group_screen.dart';

// 匯入自訂的 UI 積木
import 'package:jpn_learning_app/widgets/study_group/invite_friend_card.dart';

class InviteGroupMembersScreen extends StatefulWidget {
  final int? groupId;
  final String? newGroupName;
  final String? goalType;
  final int? goalTarget;

  const InviteGroupMembersScreen({
    Key? key,
    this.groupId,
    this.newGroupName,
    this.goalType,
    this.goalTarget,
  }) : super(key: key);

  @override
  State<InviteGroupMembersScreen> createState() => _InviteGroupMembersScreenState();
}

class _InviteGroupMembersScreenState extends State<InviteGroupMembersScreen> {
  static const Color subText = Color(0xFF6E6E6E);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  // ==========================================
  // 📡 API 呼叫區塊
  // ==========================================

  // 1. 抓取好友名單與邀請狀態
  Future<void> _fetchFriends() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    try {
      final result = await ApiClient.getFriendsDetailedInvitationStatus(widget.groupId, userId);

      if (mounted) {
        setState(() {
          if (result.containsKey('friends')) {
            _friends = (result['friends'] as List).map((f) {
              return {
                'username': f['username']?.toString(),
                'nickname': f['nickname']?.toString(),
                'id': f['friend_id']?.toString() ?? '',
                'avatar': f['avatar']?.toString() ?? '',
                'invited': false, // 畫面上的「已選取」狀態 (預設 false)
                'has_group': f['has_group'] ?? false,
                'is_invited': f['is_invited'] ?? false, // 後端傳來的「已發送邀請」狀態
                'japanese_level': f['japanese_level']?.toString(),
              };
            }).toList();
          } else if (result.containsKey('error')) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('抓取名單失敗：${result['error']}')));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 取消邀請的動作
  Future<void> _cancelInvite(String friendIdStr) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || widget.groupId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.cancelGroupInvite(widget.groupId!, friendIdStr);

      if (mounted) {
        if (result.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消邀請')));
          // 成功取消後，重新抓取名單更新畫面狀態
          await _fetchFriends(); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消失敗，請稍後再試')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. 送出按鈕動作 (建立小組 OR 邀請加入現有小組)
  Future<void> _submitAction(int selectedCount) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    // 先判斷是不是「建立小組」
    final isCreating = widget.groupId == null;

    // 如果是建立小組，才需要檢查免費額度跟收押金
    if (isCreating) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('檢查額度中...')));
      final bool isFree = await ApiClient.checkFreeQuota(userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // 如果「不是」免費的，跳出押金警告窗
      if (!isFree) {
        final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('⚠️ 押金與對賭提醒', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              '您本週的免費小組額度已用完。\n\n本次建立將會扣除 20 J-Pts 作為對賭押金（小組達標後退還）。\n\n確定要繼續嗎？',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('先不要', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('確定繼續', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;

        if (!confirm) return; // 玩家按取消就終止
      }
    }

    // --- 準備發送 API ---
    final selectedFriendIds = _friends
        .where((f) => f['invited'] == true)
        .map((f) => f['id'].toString())
        .toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isCreating ? '正在建立小組中...' : '正在發送邀請...')),
    );

    Map<String, dynamic> result;

    if (isCreating) {
      // 執行建立小組 API
      final finalGroupName = widget.newGroupName ?? '日語學習小隊';
      final finalGoalType = widget.goalType ?? 'scans';
      final finalGoalTarget = widget.goalTarget ?? 30;

      result = await ApiClient.createGroup(
        userId,
        finalGroupName,
        selectedFriendIds,
        finalGoalType,
        finalGoalTarget,
      );
    } else {
      // 執行單純邀請 API
      result = await ApiClient.inviteToExistingGroup(widget.groupId!, userId, selectedFriendIds);
    }

    // --- 處理 API 回傳結果 ---
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      } else {
        // 如果有扣款，更新錢包餘額
        if (result.containsKey('new_j_pts')) {
           context.read<UserProvider>().setJPts(result['new_j_pts']);
        }

        if (!isCreating) {
          // 單純邀請的成功畫面
          final successMessage = result['message'] ?? '邀請已順利送出！';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
          Navigator.pop(context); 
        } else {
          // 建立小組的成功畫面
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('小組建立成功！')));
          Navigator.of(context).popUntil((route) => route.isFirst);
          Future.delayed(const Duration(milliseconds: 150), () {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyGroupScreen()),
              );
            }
          });
        }
      }
    }
  }

  // ==========================================
  // 🔍 邏輯運算區塊
  // ==========================================

  // 本地搜尋過濾器
  List<Map<String, dynamic>> get _filteredFriends {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _friends;
    
    return _friends.where((friend) {
      final originalName = friend['username']?.toString().toLowerCase() ?? '';
      final nickname = friend['nickname']?.toString().toLowerCase() ?? '';
      final id = friend['id'].toString().toLowerCase();
      
      return originalName.contains(keyword) || nickname.contains(keyword) || id.contains(keyword);
    }).toList();
  }

  // ==========================================
  // 🎨 UI 渲染區塊
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final selectedCount = _friends.where((e) => e['invited'] == true).length;
    final isCreating = widget.groupId == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '邀請好友加入小組(2/2)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.9),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: selectedCount == 0 ? null : () => _submitAction(selectedCount),
              child: Text(
                isCreating ? '確認建立小組 ($selectedCount 位)' : '發送邀請 ($selectedCount 位)',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // 搜尋列
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋好友名稱或 ID',
                      hintStyle: const TextStyle(color: Color(0x80333333)),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                
                // 列表區塊
                if (_friends.isEmpty)
                  const Expanded(child: Center(child: Text('目前還沒有好友可以邀請喔！', style: TextStyle(color: subText, fontSize: 16))))
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      itemCount: _filteredFriends.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final friend = _filteredFriends[index];
                        final String friendIdStr = friend['id'].toString();
                        
                        // 渲染好友卡片積木
                        return InviteFriendCard(
                          friend: friend,
                          onToggleInvite: () {
                            setState(() {
                              if (friend['invited'] == true) {
                                friend['invited'] = false;
                              } else {
                                final currentSelected = _friends.where((e) => e['invited'] == true).length;
                                if (currentSelected < 4) {
                                  friend['invited'] = true;
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最多只能邀請 4 位好友喔！')));
                                }
                              }
                            });
                          },
                          // 綁定取消邀請邏輯
                          onCancelInvite: () => _cancelInvite(friendIdStr), 
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
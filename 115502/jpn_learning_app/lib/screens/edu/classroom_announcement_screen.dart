import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/edu/assignment_detail_screen.dart';

/// 教室公告：老師在後台發布的公告，新的在前。
///
/// 資料來源：`GET /api/classroom/<id>/announcements?user_id=`
/// 打開這頁就算看過，回到教室清單時紅點會消失。
/// 出作業時自動發的公告帶 assignment_id，可以直接點進作業詳情。
///
/// 推播通知點進來時開的是這個整頁版；教室頁的「公告」分頁直接放 [ClassroomAnnouncementList]。
class ClassroomAnnouncementScreen extends StatelessWidget {
  final int classroomId;
  final String classroomName;

  const ClassroomAnnouncementScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: Text(classroomName),
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
      ),
      body: ClassroomAnnouncementList(classroomId: classroomId),
    );
  }
}

/// 公告清單本體。第一次顯示時才向後端要資料（同時把這班公告標成已讀），
/// 所以放在分頁裡時，學生沒切到「公告」就不會被當成讀過。
class ClassroomAnnouncementList extends StatefulWidget {
  final int classroomId;

  /// 載入成功（公告已標成已讀）時通知外層，教室頁可以拿掉分頁上的紅點
  final VoidCallback? onSeen;

  const ClassroomAnnouncementList({super.key, required this.classroomId, this.onSeen});

  @override
  State<ClassroomAnnouncementList> createState() => _ClassroomAnnouncementListState();
}

class _ClassroomAnnouncementListState extends State<ClassroomAnnouncementList>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  // 在分頁之間切換時保留已載入的清單，不要每次切回來都重抓
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '請先登入';
      });
      return;
    }
    final res = await ApiClient.getClassroomAnnouncements(widget.classroomId, userId);
    if (!mounted) return;
    if (res['status'] == 'success') {
      setState(() {
        _items = (res['announcements'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
        _error = null;
      });
      widget.onSeen?.call();
    } else {
      setState(() {
        _isLoading = false;
        _error = res['error']?.toString() ?? '公告載入失敗';
      });
    }
  }

  /// 後端回傳台灣時間的 ISO 字串，只取到分鐘
  String _formatTime(String? iso) {
    final dt = iso == null ? null : DateTime.tryParse(iso);
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _openAssignment(int assignmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: assignmentId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(onRefresh: _load, child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!, style: const TextStyle(color: Colors.grey))),
          Center(child: TextButton(onPressed: _load, child: const Text('重新載入'))),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.campaign_outlined, size: 52, color: AppColors.primaryLight2),
          SizedBox(height: 10),
          Center(child: Text('老師還沒有發布公告', style: TextStyle(color: Colors.grey))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final n = _items[i];
        final isNew = n['is_new'] == true;
        final content = (n['content'] ?? '').toString();
        final assignmentId = (n['assignment_id'] as num?)?.toInt();
        // 出作業時自動發的公告整張卡片都能點進作業；「作業 ›」放在日期同一行，
        // 不另外佔一行，兩種公告的卡片高度才會一樣
        return Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isNew ? AppColors.primaryLight2 : Colors.grey.shade200, width: isNew ? 1.5 : 1),
          ),
          child: InkWell(
            onTap: assignmentId == null ? null : () => _openAssignment(assignmentId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n['title']?.toString() ?? '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (isNew)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('新', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatTime(n['created_at']?.toString()),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      if (assignmentId != null)
                        const Text(
                          '作業 ›',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(content, style: const TextStyle(height: 1.6)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

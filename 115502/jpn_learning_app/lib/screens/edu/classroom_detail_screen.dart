import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/edu/assignment_tile.dart';
import 'package:jpn_learning_app/screens/edu/assignment_detail_screen.dart';
import 'package:jpn_learning_app/screens/edu/classroom_announcement_screen.dart';

const _pageBg = Color(0xFFF4F7F5);

/// 教室頁（參考 TronClass 的課程頁）：上方是班級資訊，下面分「作業／公告／成績」三個分頁。
///
/// [classroom] 直接用教室清單那一筆（`GET /api/classroom/my/<id>`），班名、老師、說明、人數都在裡面，
/// 不用再打一次 API。各分頁的資料各自載入：
///   作業  `GET /api/assignment/my/<user_id>?classroom_id=`
///   公告  `GET /api/classroom/<id>/announcements`（切到這頁才載入，才算讀過）
///   成績  `GET /api/classroom/<id>/grades`
class ClassroomDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classroom;

  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _unread;
  bool _showFullDescription = false;

  /// 從任何分頁進作業詳情回來就 +1，作業、成績分頁聽到後靜靜重抓（剛交的作業兩邊都要更新）
  final ValueNotifier<int> _dataVersion = ValueNotifier(0);

  int get _classroomId => (widget.classroom['classroom_id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _unread = (widget.classroom['unread_count'] as num?)?.toInt() ?? 0;
    // 有新公告就直接停在「公告」，跟清單卡片上的「N 則新公告」對得上
    _tabs = TabController(length: 3, vsync: this, initialIndex: _unread > 0 ? 1 : 0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _dataVersion.dispose();
    super.dispose();
  }

  void _openAssignment(int assignmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: assignmentId)),
    ).then((_) => _dataVersion.value++);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classroom;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        title: Text(c['name']?.toString() ?? '教室'),
        backgroundColor: _pageBg,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(c),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              const Tab(text: '作業'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('公告'),
                    if (_unread > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
              const Tab(text: '成績'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AssignmentsTab(
                  classroomId: _classroomId,
                  dataVersion: _dataVersion,
                  onOpen: _openAssignment,
                ),
                ClassroomAnnouncementList(
                  classroomId: _classroomId,
                  onSeen: () {
                    if (mounted && _unread > 0) setState(() => _unread = 0);
                  },
                ),
                _GradesTab(
                  classroomId: _classroomId,
                  dataVersion: _dataVersion,
                  onOpen: _openAssignment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 頂端只放學生用得到的：哪位老師、老師寫的班級說明。
  /// 同學人數、加入日期、教室代碼對學生沒什麼用，不放
  Widget _buildHeader(Map<String, dynamic> c) {
    final teacher = c['teacher_name']?.toString() ?? '老師';
    final description = (c['description'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '老師：$teacher',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            // 說明可能很長，先收成三行，點一下展開
            GestureDetector(
              onTap: () => setState(() => _showFullDescription = !_showFullDescription),
              child: Text(
                description,
                maxLines: _showFullDescription ? null : 3,
                overflow: _showFullDescription ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 分頁共用：轉圈、錯誤、空白狀態也要能下拉重新整理
Widget _messageList(String text, {VoidCallback? onRetry}) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 100),
      Center(
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.6)),
      ),
      if (onRetry != null) Center(child: TextButton(onPressed: onRetry, child: const Text('重新載入'))),
    ],
  );
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
  );
}

// ==========================================
// 作業
// ==========================================
class _AssignmentsTab extends StatefulWidget {
  final int classroomId;
  final ValueNotifier<int> dataVersion;
  final void Function(int assignmentId) onOpen;

  const _AssignmentsTab({required this.classroomId, required this.dataVersion, required this.onOpen});

  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    widget.dataVersion.addListener(_reload);
  }

  @override
  void dispose() {
    widget.dataVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '請先登入';
      });
      return;
    }
    if (showSpinner) setState(() => _isLoading = true);
    try {
      // 這裡只拿一班的作業，不重排截止提醒：提醒是整份清單一起排的，只給一班會把別班的提醒洗掉
      final data = await ApiClient.getStudentAssignments(userId, classroomId: widget.classroomId);
      if (!mounted) return;
      setState(() {
        _items = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '無法載入作業，請稍後再試';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(onRefresh: () => _load(showSpinner: false), child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _messageList(_error!, onRetry: _load);
    if (_items.isEmpty) return _messageList('老師還沒有出作業');

    bool isTodo(Map<String, dynamic> t) => (t['submission']?['status'] ?? 'pending') == 'pending';
    final todo = _items.where(isTodo).toList();
    final done = _items.where((t) => !isTodo(t)).toList();

    Widget tile(Map<String, dynamic> t) {
      final id = (t['assignment_id'] as num?)?.toInt();
      return AssignmentTile(
        task: t,
        showClassroom: false,
        onTap: id == null ? null : () => widget.onOpen(id),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _sectionTitle(todo.isEmpty ? '待完成：都交了！' : '待完成 ${todo.length}'),
        ...todo.map(tile),
        if (done.isNotEmpty) ...[
          _sectionTitle('已繳交 ${done.length}'),
          ...done.map(tile),
        ],
      ],
    );
  }
}

// ==========================================
// 成績
// ==========================================
class _GradesTab extends StatefulWidget {
  final int classroomId;
  final ValueNotifier<int> dataVersion;
  final void Function(int assignmentId) onOpen;

  const _GradesTab({required this.classroomId, required this.dataVersion, required this.onOpen});

  @override
  State<_GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<_GradesTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    widget.dataVersion.addListener(_reload);
  }

  @override
  void dispose() {
    widget.dataVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '請先登入';
      });
      return;
    }
    if (showSpinner) setState(() => _isLoading = true);
    final res = await ApiClient.getClassroomGrades(widget.classroomId, userId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res['status'] == 'success') {
        _data = res;
        _error = null;
      } else {
        _error = res['error']?.toString() ?? '成績載入失敗';
      }
    });
  }

  /// 82.0 顯示成 82，82.5 照原樣
  String _num(num? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(onRefresh: () => _load(showSpinner: false), child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _data == null) return _messageList(_error ?? '成績載入失敗', onRetry: _load);

    final rows = (_data!['assignments'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (rows.isEmpty) return _messageList('老師還沒有出作業，\n目前沒有成績');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildSummary(Map<String, dynamic>.from(_data!['summary'] as Map)),
        const SizedBox(height: 8),
        _sectionTitle('各作業成績'),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _buildRow(rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(Map<String, dynamic> s) {
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final submitted = (s['submitted'] as num?)?.toInt() ?? 0;
    final graded = (s['graded'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('繳交進度', style: TextStyle(fontWeight: FontWeight.bold))),
              Text('$submitted / $total 份', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : submitted / total,
              minHeight: 8,
              backgroundColor: AppColors.primaryLighter,
              color: AppColors.primaryLight2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            graded == 0 ? '還沒有批改完成的作業' : '已批改 $graded 份，平均 ${_num(s['graded_avg'] as num?)} 分',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'missing';
    final deduct = (r['deduct'] as num?)?.toInt() ?? 0;
    final comment = (r['teacher_comment'] ?? '').toString().trim();
    final id = (r['assignment_id'] as num?)?.toInt();

    Widget trailing;
    if (status == 'graded') {
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${_num(r['effective'] as num?)} 分',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          if (deduct > 0)
            Text('遲交 -$deduct', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
      );
    } else if (status == 'ungraded') {
      trailing = const Text('待批閱', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
    } else {
      final overdue = r['is_overdue'] == true;
      trailing = Text(
        overdue ? '缺交' : '未繳交',
        style: TextStyle(color: overdue ? Colors.redAccent : AppColors.textGrey, fontWeight: FontWeight.bold),
      );
    }

    return ListTile(
      onTap: id == null ? null : () => widget.onOpen(id),
      title: Text(r['title']?.toString() ?? '作業', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              r['type_label']?.toString() ?? '',
              AssignmentTile.formatDue(r['due_at']?.toString()),
            ].where((t) => t.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          if (comment.isNotEmpty)
            Text(
              '老師：$comment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
        ],
      ),
      trailing: trailing,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

/// 加入教室彈窗，分兩步：
///   1. 輸入老師給的 6 碼代碼 → 查詢
///   2. 顯示「這是哪一班、哪位老師」讓學生確認 → 真正加入
/// 避免打錯一個字就加進別班，事後還要老師手動移除。
/// 加入成功會 pop(true)，呼叫端據此刷新。
class JoinClassroomDialog extends StatefulWidget {
  final int studentId;

  const JoinClassroomDialog({Key? key, required this.studentId}) : super(key: key);

  @override
  State<JoinClassroomDialog> createState() => _JoinClassroomDialogState();
}

class _JoinClassroomDialogState extends State<JoinClassroomDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _preview; // 查到的教室；null 表示還在第一步

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _lookup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('請輸入教室代碼');
      return;
    }
    setState(() => _isLoading = true);
    final res = await ApiClient.previewClassroom(code);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['status'] == 'success' && res['classroom'] is Map) {
      setState(() => _preview = Map<String, dynamic>.from(res['classroom']));
    } else {
      _showError(res['error'] ?? '找不到這個教室代碼，請再確認一次');
    }
  }

  Future<void> _join() async {
    setState(() => _isLoading = true);
    final res = await ApiClient.joinClassroom(
      userId: widget.studentId,
      joinCode: _codeController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    final data = res['data'] as Map<String, dynamic>;
    // 201 = 新加入，200 = 原本就在裡面，兩者都算成功
    if (res['statusCode'] == 201 || res['statusCode'] == 200) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? '加入成功！')),
      );
    } else {
      _showError(data['error'] ?? '加入失敗，請再確認一次');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(p == null ? '加入專屬教室' : '確認是這一班嗎？'),
      content: p == null ? _buildCodeStep() : _buildConfirmStep(p),
      actions: p == null
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _lookup,
                child: _isLoading ? _spinner() : const Text('查詢'),
              ),
            ]
          : [
              TextButton(
                onPressed: _isLoading ? null : () => setState(() => _preview = null),
                child: const Text('不是這一班', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: _isLoading || p['is_open'] == false ? null : _join,
                child: _isLoading ? _spinner() : const Text('確認加入'),
              ),
            ],
    );
  }

  Widget _spinner() => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );

  Widget _buildCodeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('請輸入老師提供的 6 碼教室代碼：'),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _isLoading ? null : _lookup(),
          decoration: InputDecoration(
            hintText: '例如：A1B2C3',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(Map<String, dynamic> p) {
    final bool isOpen = p['is_open'] != false;
    final description = (p['description'] ?? '').toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight2.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p['name'] ?? '未命名教室',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('老師：${p['teacher_name'] ?? '老師'}'),
              Text('目前 ${p['member_count'] ?? 0} 位同學'),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ],
          ),
        ),
        if (!isOpen) ...[
          const SizedBox(height: 10),
          const Text(
            '這個教室目前沒有開放加入，請聯絡老師。',
            style: TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

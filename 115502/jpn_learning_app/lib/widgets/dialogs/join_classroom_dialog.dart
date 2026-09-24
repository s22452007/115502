import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JoinClassroomDialog extends StatefulWidget {
  final int studentId; // ⚠️ 注意：根據後端邏輯，ID 通常是整數 (int) 或字串，請依照你專案的型別調整

  const JoinClassroomDialog({Key? key, required this.studentId}) : super(key: key);

  @override
  State<JoinClassroomDialog> createState() => _JoinClassroomDialogState();
}

class _JoinClassroomDialogState extends State<JoinClassroomDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinClassroom() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入教室代碼')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 假設你的 Flask 跑在 5050 port，且 blueprint 註冊在 /api/classroom
      final url = Uri.parse('http://127.0.0.1:5050/api/classroom/join'); 
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.studentId, // 🌟 配合後端的 user_id 參數
          'join_code': code,           // 🌟 配合後端的 join_code 參數
        }),
      );

      final data = jsonDecode(response.body);

      // 後端回傳 201 代表成功建立關聯，回傳 200 代表原本就已經加入了
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); // 關閉彈窗並回傳 true
        ScaffoldMessenger.of(context).showSnackBar(
          // 顯示後端客製化的成功或提示訊息 (例如："已加入「日語初級班」")
          SnackBar(content: Text(data['message'] ?? '加入成功！')), 
        );
      } else {
        // 處理 400, 403, 404 錯誤 (後端是用 'error' 欄位傳遞錯誤訊息)
        final errorMsg = data['error'] ?? '加入失敗，請再確認一次';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('網路發生錯誤，請檢查後端伺服器是否開啟')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('加入專屬教室'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('請輸入老師提供的隨機教室碼：'),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: '例如：A1B2C3',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            // 組員後端有做正規化，但前端直接自動轉大寫可以讓使用者體驗更好
            textCapitalization: TextCapitalization.characters, 
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _joinClassroom,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('確認加入'),
        ),
      ],
    );
  }
}
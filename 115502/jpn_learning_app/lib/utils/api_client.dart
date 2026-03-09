import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // 因為你是用 Chrome 測試 Flutter，所以可以直接用 127.0.0.1
  // (注意：如果你之後改用 Android 模擬器，這裡要改成 10.0.2.2)
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  // --- 註冊 API ---
  static Future<Map<String, dynamic>> register(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('註冊連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // --- 登入 API ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('登入連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // --- 重設密碼 API ---
  static Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    final url = Uri.parse('$baseUrl/auth/reset_password');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email, 
          'new_password': newPassword
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('重設密碼連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 傳送測驗分數給後端的 API
  static Future<Map<String, dynamic>> submitQuizScore(int userId, int score) async {
    final url = Uri.parse('$baseUrl/quiz/submit');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'score': score,
        }),
      );

      if (response.statusCode == 200) {
        // 成功的話，把後端回傳的 JSON 解析出來
        return jsonDecode(response.body);
      } else {
        print('後端回傳錯誤代碼: ${response.statusCode}');
        return {'error': '請求失敗'};
      }
    } catch (e) {
      print('連線失敗: $e');
      return {'error': e.toString()};
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // 因為你是用 Chrome 測試 Flutter，所以可以直接用 127.0.0.1
  // (注意：如果你之後改用 Android 模擬器，這裡要改成 10.0.2.2)
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  //  註冊 API
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
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

  //  登入 API
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
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

  //  重設密碼 API
  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    final url = Uri.parse('$baseUrl/auth/reset_password');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'new_password': newPassword}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('重設密碼連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  //  新增：直接更新日語程度 API
  static Future<Map<String, dynamic>> updateLevel(
    int userId,
    String level,
  ) async {
    final url = Uri.parse('$baseUrl/auth/update_level');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'level': level}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('更新程度連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 傳送測驗分數給後端的 API
  static Future<Map<String, dynamic>> submitQuizScore(
    int userId,
    int score,
  ) async {
    final url = Uri.parse('$baseUrl/quiz/submit');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'score': score}),
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

  // 上傳大頭貼
  static Future<Map<String, dynamic>> uploadAvatar(
    int userId,
    String avatarBase64,
  ) async {
    final url = Uri.parse('$baseUrl/auth/upload_avatar');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'avatar': avatarBase64}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('上傳大頭貼連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 抓取個人檔案資料 API
  static Future<Map<String, dynamic>> fetchProfileData(int userId) async {
    final url = Uri.parse('$baseUrl/auth/profile_data/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': '請求失敗'};
      }
    } catch (e) {
      print('抓取個人檔案失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 抓取使用者收藏資料夾 API
  static Future<Map<String, dynamic>> fetchUserFavorites(int userId) async {
    final url = Uri.parse('$baseUrl/auth/favorites/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': '請求失敗'};
      }
    } catch (e) {
      print('抓取收藏夾失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 建立自訂資料夾 API
  static Future<Map<String, dynamic>> createFolder(
    int userId,
    String folderName,
  ) async {
    final url = Uri.parse('$baseUrl/auth/folders');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'name': folderName}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('建立資料夾失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // --- 新增：上傳場景照片給 AI 分析 API ---
  static Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    final url = Uri.parse('$baseUrl/scenario/analyze');

    try {
      // 使用 MultipartRequest 來上傳檔案
      var request = http.MultipartRequest('POST', url);

      // 將圖片檔案加入請求中
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      // 發送請求
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 500) {
        return jsonDecode(response.body);
      } else {
        return {'error': '伺服器錯誤代碼: ${response.statusCode}'};
      }
    } catch (e) {
      print('上傳圖片連線失敗: $e');
      return {'error': '網路連線失敗: $e'};
    }
  }
}

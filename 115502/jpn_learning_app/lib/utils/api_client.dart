import 'dart:convert';
import 'package:http/http.dart' as http;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  // 動態判斷平台，自動切換對應的本地端 IP
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    } else {
      return 'http://127.0.0.1:5000/api';
    }
  }

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

  // 上傳場景照片給 AI 分析 API
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

  // 搜尋好友 API
  static Future<Map<String, dynamic>> searchFriend(String friendId) async {
    final url = Uri.parse('$baseUrl/auth/search_friend');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'friend_id': friendId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('搜尋好友失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 發送交友邀請 API
  static Future<Map<String, dynamic>> sendFriendRequest(
    int senderId,
    int receiverId,
  ) async {
    final url = Uri.parse('$baseUrl/auth/friend_request/send');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sender_id': senderId, 'receiver_id': receiverId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  // 讀取待確認的邀請 API
  static Future<Map<String, dynamic>> getPendingRequests(int userId) async {
    final url = Uri.parse('$baseUrl/auth/friend_request/pending/$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  // 同意或拒絕邀請 API
  static Future<Map<String, dynamic>> respondFriendRequest(
    int requestId,
    String action,
  ) async {
    final url = Uri.parse('$baseUrl/auth/friend_request/respond');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'request_id': requestId, 'action': action}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  // 取得好友列表 API
  static Future<Map<String, dynamic>> getFriendsList(int userId) async {
    final url = Uri.parse('$baseUrl/auth/friends/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 💰 購買點數 API
  static Future<Map<String, dynamic>> buyPoints(int userId, int points) async {
    final url = Uri.parse('$baseUrl/auth/add_points');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'points': points}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('購買點數連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 📸 增加今日拍照進度 API
  static Future<Map<String, dynamic>> incrementDailyScan(int userId) async {
    final url = Uri.parse('$baseUrl/auth/increment_scan');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('更新進度連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 🛡️ 建立學習小組 (公會) API
  static Future<Map<String, dynamic>> createGroup(
    int hostId,
    String groupName,
    List<String> friendIds,
  ) async {
    final url = Uri.parse('$baseUrl/auth/group/create');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host_id': hostId,
          'name': groupName,
          'friend_ids': friendIds,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('建立小組失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 🛡️ 抓取我的學習小組 (公會) API
  static Future<Map<String, dynamic>> getMyGroup(int userId) async {
    final url = Uri.parse('$baseUrl/auth/group/my_group/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': '請求失敗'};
      }
    } catch (e) {
      print('讀取小組失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }
}

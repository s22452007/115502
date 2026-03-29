import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiClient {
  // 動態判斷平台，自動切換對應的本地端 IP
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    } else {
      return 'http://127.0.0.1:5000/api';
    }
  }

  // 註冊 API
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

  // 登入 API
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

  // Google 登入 / 同步會員 API
  // 後端規格：
  // POST /api/auth/google_login
  // body: {"email": "...", "avatar": "...(選填)"}
  static Future<Map<String, dynamic>> googleLogin(
    String email, {
    String? avatar,
  }) async {
    final url = Uri.parse('$baseUrl/auth/google_login');
    try {
      final body = <String, dynamic>{'email': email};

      if (avatar != null && avatar.isNotEmpty) {
        body['avatar'] = avatar;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Google 登入同步失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 重設密碼 API
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

  // 直接更新日語程度 API
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
      var request = http.MultipartRequest('POST', url);

      if (kIsWeb) {
        // Web 平台的 imagePath 通常是 blob: URL，我們需要先抓取它的 bytes
        final imageResponse = await http.get(Uri.parse(imagePath));
        final bytes = imageResponse.bodyBytes;
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'web_image.jpg',
          ),
        );
      } else {
        // Android/iOS 可以直接使用實體檔案路徑
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
      }

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

  // 購買點數 API
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

  // 增加今日拍照進度 API
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

  // 建立學習小組 (公會) API
  static Future<Map<String, dynamic>> createGroup(
    int hostId,
    String groupName,
    List<String> friendIds,
    String goalType, // 接收目標類型
    int goalTarget, // 接收目標數值
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
          'goal_type': goalType,
          'goal_target': goalTarget,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('建立小組失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 抓取我的學習小組 (公會) API
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

  // 抓取收到的小組邀請 API
  static Future<Map<String, dynamic>> getGroupInvites(int userId) async {
    final url = Uri.parse('$baseUrl/auth/group/invites/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'invites': []};
      }
    } catch (e) {
      print('讀取小組邀請失敗: $e');
      return {'error': '網路連線失敗', 'invites': []};
    }
  }

  // 回應小組邀請 API
  static Future<Map<String, dynamic>> respondGroupInvite(
    int inviteId,
    String action,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/auth/group/respond_invite');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'invite_id': inviteId,
          'action': action,
          'user_id': userId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('回應小組邀請失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 邀請好友加入現有小組 API
  static Future<Map<String, dynamic>> inviteToExistingGroup(
    int groupId,
    int senderId,
    List<String> friendIds,
  ) async {
    final url = Uri.parse('$baseUrl/auth/group/invite_friends');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'group_id': groupId,
          'sender_id': senderId,
          'friend_ids': friendIds,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('發送邀請失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // 抓取包含邀請狀態的詳細好友名單
  static Future<Map<String, dynamic>> getFriendsDetailedInvitationStatus(
    int? groupId,
    int userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/group/friends_detailed_status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'group_id': groupId ?? -1, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': '無法抓取詳細好友狀態 (${response.statusCode})'};
      }
    } catch (e) {
      print('getFriendsDetailedInvitationStatus error: $e');
      return {'error': '無法連線到伺服器'};
    }
  }

  // 檢查暱稱是否可用 API
  static Future<Map<String, dynamic>> checkUsername(
    String username, {
    int? userId,
  }) async {
    final url = Uri.parse('$baseUrl/auth/check_username');
    try {
      final body = <String, dynamic>{'username': username};
      if (userId != null) body['user_id'] = userId;
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 更新暱稱 API
  static Future<Map<String, dynamic>> updateUsername(
    int userId,
    String username,
  ) async {
    final url = Uri.parse('$baseUrl/auth/update_username');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'username': username}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 刪除帳號 API
  static Future<Map<String, dynamic>> deleteAccount(int userId) async {
    final url = Uri.parse('$baseUrl/user/delete_account');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 退出小組 API
  static Future<Map<String, dynamic>> leaveGroup(
    int groupId,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/auth/group/leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'group_id': groupId, 'user_id': userId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('退出小組失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }
}

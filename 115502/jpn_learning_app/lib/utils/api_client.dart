import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiClient {
  // 動態判斷平台，自動切換對應的本地端 IP
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5050/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5050/api';
    } else {
      return 'http://127.0.0.1:5050/api';
    }
  }

  // ==========================================
  // 🔐 登入與註冊相關
  // ==========================================

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

  // ==========================================
  // 👤 使用者個人資料與設定相關
  // ==========================================

  // 直接更新日語程度 API
  static Future<Map<String, dynamic>> updateLevel(
    int userId,
    String level,
  ) async {
    final url = Uri.parse('$baseUrl/user/update_level');
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

  // 上傳大頭貼
  static Future<Map<String, dynamic>> uploadAvatar(
    int userId,
    String avatarBase64,
  ) async {
    final url = Uri.parse('$baseUrl/user/upload_avatar');
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
    final url = Uri.parse('$baseUrl/user/profile_data/$userId');
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

  // 檢查暱稱是否可用 API
  static Future<Map<String, dynamic>> checkUsername(
    String username, {
    int? userId,
  }) async {
    final url = Uri.parse('$baseUrl/user/check_username');
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
    final url = Uri.parse('$baseUrl/user/update_username');
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

  // 送出意見回饋 API
  static Future<Map<String, dynamic>> submitFeedback({
    int? userId,
    String? email,
    required String feedbackType,
    required String content,
  }) async {
    final url = Uri.parse('$baseUrl/user/feedback');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'email': email,
          'feedback_type': feedbackType,
          'content': content,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 查詢歷史回饋 API
  static Future<Map<String, dynamic>> getFeedbacks(int userId) async {
    final url = Uri.parse('$baseUrl/user/feedback/$userId');
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

  // 購買/增加點數 API
  static Future<Map<String, dynamic>> buyPoints(
    int userId,
    int points, {
    int price = 0,
    String paymentMethod = 'unknown',
  }) async {
    final url = Uri.parse('$baseUrl/user/add_points');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'points': points,
          'price': price,
          'payment_method': paymentMethod,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 查詢交易紀錄 API
  static Future<Map<String, dynamic>> getTransactions(int userId) async {
    final url = Uri.parse('$baseUrl/user/transactions/$userId');
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

  // 增加今日拍照進度 API
  static Future<Map<String, dynamic>> incrementDailyScan(int userId) async {
    final url = Uri.parse('$baseUrl/user/increment_scan');
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

  // 這個徽章的升級彈窗我看過了！
  static Future<void> markBadgeSeen(
    int userId,
    String badgeId,
    int level,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/user/mark_badge_seen');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'badge_id': badgeId,
          'level': level,
        }),
      );
    } catch (e) {
      print('標記徽章已讀失敗: $e');
    }
  }

  // ==========================================
  // 🤝 好友系統相關
  // ==========================================

  // 搜尋好友 API
  static Future<Map<String, dynamic>> searchFriend(String friendId) async {
    final url = Uri.parse('$baseUrl/user/search_friend');
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
    final url = Uri.parse('$baseUrl/user/friend_request/send');
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
    final url = Uri.parse('$baseUrl/user/friend_request/pending/$userId');
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
    final url = Uri.parse('$baseUrl/user/friend_request/respond');
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
    final url = Uri.parse('$baseUrl/user/friends/$userId');
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

  // ==========================================
  // 🛡️ 學習小組 (公會) 系統相關
  // ==========================================

  // 建立學習小組 API
  static Future<Map<String, dynamic>> createGroup(
    int hostId,
    String groupName,
    List<String> friendIds,
    String goalType,
    int goalTarget,
  ) async {
    final url = Uri.parse('$baseUrl/group/create');
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

  // 抓取我的學習小組 API
  static Future<Map<String, dynamic>> getMyGroup(int userId) async {
    final url = Uri.parse('$baseUrl/group/my_group/$userId');
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
    final url = Uri.parse('$baseUrl/group/invites/$userId');
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
    final url = Uri.parse('$baseUrl/group/respond_invite');
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
    final url = Uri.parse('$baseUrl/group/invite_friends');
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

  // 抓取包含邀請狀態的詳細好友名單 API
  static Future<Map<String, dynamic>> getFriendsDetailedInvitationStatus(
    int? groupId,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/group/friends_detailed_status');
    try {
      final response = await http.post(
        url,
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

  // 退出/解散小組 API
  static Future<Map<String, dynamic>> leaveGroup(
    int groupId,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/group/leave');
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

  // 偷偷檢查這週是否還有免費小組額度
  static Future<bool> checkFreeQuota(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/group/check_quota/$userId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_free'] ?? false;
      }
      return false; // 如果有問題，預設當作要扣錢 (比較安全)
    } catch (e) {
      print('檢查額度發生錯誤: $e');
      return false;
    }
  }

  // ==========================================
  // 📚 單字本與收藏夾相關
  // ==========================================

  // 抓取使用者收藏資料夾 API
  static Future<Map<String, dynamic>> fetchUserFavorites(int userId) async {
    final url = Uri.parse('$baseUrl/vocab/favorites/$userId');
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
    final url = Uri.parse('$baseUrl/vocab/folders');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'name': folderName}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 取得資料夾內的單字
  static Future<Map<String, dynamic>> getFolderVocabs(
    int userId, {
    int? folderId,
  }) async {
    final url = Uri.parse('$baseUrl/vocab/folder_vocabs');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'folder_id': folderId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 移動單字到資料夾
  static Future<Map<String, dynamic>> moveVocab(
    int userVocabId, {
    int? targetFolderId,
  }) async {
    final url = Uri.parse('$baseUrl/vocab/move_vocab');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_vocab_id': userVocabId,
          'target_folder_id': targetFolderId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 收藏單字（可選資料夾）
  static Future<Map<String, dynamic>> collectVocab(
    int userId,
    int vocabId, {
    int? folderId,
  }) async {
    final url = Uri.parse('$baseUrl/vocab/collect');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'vocab_id': vocabId,
          'folder_id': folderId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 取消收藏單字
  static Future<bool> removeFavorite(int vocabId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/uncollect');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'vocab_id': vocabId}),
      );

      if (response.statusCode == 200) {
        return true; // 成功取消
      } else {
        return false;
      }
    } catch (e) {
      print('取消收藏失敗: $e');
      return false;
    }
  }

  // 刪除資料夾
  static Future<Map<String, dynamic>> deleteFolder(int folderId) async {
    final url = Uri.parse('$baseUrl/vocab/delete_folder');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'folder_id': folderId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 重新命名資料夾
  static Future<Map<String, dynamic>> renameFolder(
    int folderId,
    String name,
  ) async {
    final url = Uri.parse('$baseUrl/vocab/rename_folder');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'folder_id': folderId, 'name': name}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // 取得解鎖場景
  static Future<List<dynamic>> getUnlockedScenes(
    int userId, {
    int limit = 3,
  }) async {
    final url = Uri.parse('$baseUrl/scenario/unlocked/$userId?limit=$limit');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['scenes'];
    } else {
      throw Exception('無法載入解鎖場景');
    }
  }

  // 取得場景單字清單
  static Future<List<dynamic>> getSceneVocabs(int sceneId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/scene/$sceneId?user_id=$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['vocabs'];
    } else {
      throw Exception('無法載入單字清單');
    }
  }

  // 取得「特定照片」解鎖的單字清單
  static Future<List<dynamic>> getVocabsByPhoto(
    String imagePath,
    int userId,
  ) async {
    // 記得將字串 encode，避免檔名有特殊字元
    final encodedPath = Uri.encodeComponent(imagePath);
    final url = Uri.parse(
      '$baseUrl/scenario/photo_vocabs?user_id=$userId&image_path=$encodedPath',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['vocabs'];
    } else {
      throw Exception('無法載入此照片的單字清單');
    }
  }

  // 取得單字詳細資訊
  static Future<Map<String, dynamic>> getVocabDetail(
    int vocabId,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/vocab/detail/$vocabId?user_id=$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('無法載入單字詳細資訊');
    }
  }

  // 收藏單字
  static Future<bool> toggleFavorite(int vocabId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/collect');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'vocab_id': vocabId}),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      return false;
    }
  }

  // ==========================================
  // 🤖 其他 AI 與測驗功能
  // ==========================================

  // 🚀 新增：從後端資料庫抓取 10 題隨機題庫
  static Future<List<dynamic>> fetchQuizQuestions() async {
    final url = Uri.parse('$baseUrl/quiz/questions');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['questions'] ?? [];
      } else {
        print('後端抓取題目失敗: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('連線失敗: $e');
      return [];
    }
  }

  // 傳送 10 題階梯式測驗陣列給後端的 API
  static Future<Map<String, dynamic>> submitQuizResults(
    int userId,
    List<bool> results,
  ) async {
    final url = Uri.parse('$baseUrl/quiz/submit');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'results': results}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': '伺服器錯誤: ${response.statusCode}'};
      }
    } catch (e) {
      print('連線失敗: $e');
      return {'error': '無法連線到伺服器: $e'};
    }
  }

  // 原本的單純傳送分數 API (保留以防其他地方還在使用)
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

  // 上傳場景照片給 AI 分析 API
  static Future<Map<String, dynamic>> analyzeImage(
    String imagePath,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/scenario/analyze');
    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['user_id'] = userId.toString();

      if (kIsWeb) {
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

  // 重新命名照片標題 API
  // 領取小組獎勵 API
  static Future<Map<String, dynamic>> claimReward(
    int groupId,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/group/claim_reward');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'group_id': groupId, 'user_id': userId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('領獎失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }

  // --- AI 家教問答 API ---
  static Future<Map<String, dynamic>> askTutorQuestion(String question) async {
    final url = Uri.parse('$baseUrl/tutor/ask');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': '後端錯誤: ${response.statusCode}'};
      }
    } catch (e) {
      print('AI 家教問答連線失敗: $e');
      return {'error': '網路連線失敗'};
    }
  }
}

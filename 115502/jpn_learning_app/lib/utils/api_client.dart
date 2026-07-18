import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;

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
  // 🔐 登入與註冊
  // ==========================================

  static Future<Map<String, dynamic>> register(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> googleLogin(String email, {String? avatar}) async {
    final url = Uri.parse('$baseUrl/auth/google_login');
    try {
      final body = <String, dynamic>{'email': email};
      if (avatar != null && avatar.isNotEmpty) body['avatar'] = avatar;
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    final url = Uri.parse('$baseUrl/auth/reset_password');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'new_password': newPassword}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // ==========================================
  // 👤 使用者個人資料與設定相關
  // ==========================================

  static Future<Map<String, dynamic>> updateLevel(int userId, String level) async {
    final url = Uri.parse('$baseUrl/user/update_level');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'level': level}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> uploadAvatar(int userId, String avatarBase64) async {
    final url = Uri.parse('$baseUrl/user/upload_avatar');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'avatar': avatarBase64}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> fetchProfileData(int userId) async {
    final url = Uri.parse('$baseUrl/user/profile_data/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> activatePremium(int userId, {String paymentMethod = 'google_pay'}) async {
    final url = Uri.parse('$baseUrl/subscription/trial');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'payment_method': paymentMethod}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> checkUsername(String username, {int? userId}) async {
    final url = Uri.parse('$baseUrl/user/check_username');
    try {
      final body = <String, dynamic>{'username': username};
      if (userId != null) body['user_id'] = userId;
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> updateUsername(int userId, String username) async {
    final url = Uri.parse('$baseUrl/user/update_username');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'username': username}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount(int userId) async {
    final url = Uri.parse('$baseUrl/user/delete_account');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> submitFeedback({int? userId, String? email, required String feedbackType, required String content}) async {
    final url = Uri.parse('$baseUrl/user/feedback');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'email': email, 'feedback_type': feedbackType, 'content': content}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getFeedbacks(int userId) async {
    final url = Uri.parse('$baseUrl/user/feedback/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> buyPoints(int userId, int points, {int price = 0, String paymentMethod = 'unknown'}) async {
    final url = Uri.parse('$baseUrl/user/add_points');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'points': points, 'price': price, 'payment_method': paymentMethod}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getTransactions(int userId) async {
    final url = Uri.parse('$baseUrl/user/transactions/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> incrementDailyScan(int userId) async {
    final url = Uri.parse('$baseUrl/user/increment_scan');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId}));
      final data = jsonDecode(response.body);
      data['statusCode'] = response.statusCode; 
      return data;
    } catch (e) {
      return {'error': '網路連線失敗', 'statusCode': 500};
    }
  }

  static Future<Map<String, dynamic>> getUsageStatus(int userId) async {
    final url = Uri.parse('$baseUrl/user/usage_status/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'error': '無法取得使用量'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getDailyStatus(int userId) async {
    final url = Uri.parse('$baseUrl/daily/status?user_id=$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> claimDailyReward(int userId) async {
    final url = Uri.parse('$baseUrl/daily/claim');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId}));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<void> markBadgeSeen(int userId, String badgeId, int level) async {
    try {
      final url = Uri.parse('$baseUrl/user/mark_badge_seen');
      await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'badge_id': badgeId, 'level': level}));
    } catch (e) {
      debugPrint('標記徽章已讀失敗: $e');
    }
  }

  // ==========================================
  // 🤝 好友系統相關
  // ==========================================

  static Future<Map<String, dynamic>> searchFriend(String friendId) async {
    final url = Uri.parse('$baseUrl/user/search_friend');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'friend_id': friendId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> sendFriendRequest(int senderId, int receiverId) async {
    final url = Uri.parse('$baseUrl/user/friend_request/send');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'sender_id': senderId, 'receiver_id': receiverId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getPendingRequests(int userId) async {
    final url = Uri.parse('$baseUrl/user/friend_request/pending/$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> respondFriendRequest(int requestId, String action) async {
    final url = Uri.parse('$baseUrl/user/friend_request/respond');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'request_id': requestId, 'action': action}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getFriendsList(int userId) async {
    final url = Uri.parse('$baseUrl/user/friends/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> updateFriendNickname(int userId, String friendId, String newNickname) async {
    final url = Uri.parse('$baseUrl/user/friend/update_nickname');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'friend_id': friendId, 'nickname': newNickname}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> deleteFriend(int userId, String friendId) async {
    final url = Uri.parse('$baseUrl/user/friend/delete');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'friend_id': friendId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  // ==========================================
  // 🛡️ 學習小組 (公會) 系統相關
  // ==========================================

  static Future<Map<String, dynamic>> createGroup(int userId, String groupName, List<String> friendIds, String goalType, int goalTarget) async {
    final url = Uri.parse('$baseUrl/group/create');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'name': groupName, 'friend_ids': friendIds, 'goal_type': goalType, 'goal_target': goalTarget}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getMyGroup(int userId) async {
    final url = Uri.parse('$baseUrl/group/my_group/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getGroupInvites(int userId) async {
    final url = Uri.parse('$baseUrl/group/invites/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'invites': []};
    } catch (e) {
      return {'error': '網路連線失敗', 'invites': []};
    }
  }

  static Future<Map<String, dynamic>> respondGroupInvite(int inviteId, String action, int userId) async {
    final url = Uri.parse('$baseUrl/group/respond_invite');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'invite_id': inviteId, 'action': action, 'user_id': userId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> inviteToExistingGroup(int groupId, int senderId, List<String> friendIds) async {
    final url = Uri.parse('$baseUrl/group/invite_friends');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'group_id': groupId, 'sender_id': senderId, 'friend_ids': friendIds}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getFriendsDetailedInvitationStatus(int? groupId, int userId) async {
    final url = Uri.parse('$baseUrl/group/friends_detailed_status');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'group_id': groupId ?? -1, 'user_id': userId}));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '無法抓取狀態'};
    } catch (e) {
      return {'error': '無法連線'};
    }
  }

  static Future<Map<String, dynamic>> cancelGroupInvite(int groupId, String receiverId) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/group/cancel_invite'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'group_id': groupId, 'receiver_id': receiverId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> leaveGroup(int groupId, int userId) async {
    final url = Uri.parse('$baseUrl/group/leave');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'group_id': groupId, 'user_id': userId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<bool> checkFreeQuota(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/group/check_quota/$userId'));
      if (response.statusCode == 200) return json.decode(response.body)['is_free'] ?? false;
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // 📚 單字本與場景
  // ==========================================

  static Future<Map<String, dynamic>> fetchUserFavorites(int userId) async {
    final url = Uri.parse('$baseUrl/vocab/favorites/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<int?> createFolder(int userId, String folderName) async {
    final url = Uri.parse('$baseUrl/vocab/folders');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'name': folderName}));
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) return data['folder_id'];
      throw Exception(data['error'] ?? '建立失敗');
    } catch (e) {
      throw Exception('網路連線失敗');
    }
  }

  static Future<Map<String, dynamic>> getFolderVocabs(int userId, {int? folderId}) async {
    final url = Uri.parse('$baseUrl/vocab/folder_vocabs');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'folder_id': folderId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> moveVocab(int userVocabId, {int? targetFolderId}) async {
    final url = Uri.parse('$baseUrl/vocab/move_vocab');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_vocab_id': userVocabId, 'target_folder_id': targetFolderId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> collectVocab(int userId, int vocabId, {int? folderId}) async {
    final url = Uri.parse('$baseUrl/vocab/collect');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'vocab_id': vocabId, 'folder_id': folderId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<bool> removeFavorite(int vocabId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/uncollect');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: json.encode({'user_id': userId, 'vocab_id': vocabId}));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> deleteFolder(int folderId) async {
    final url = Uri.parse('$baseUrl/vocab/delete_folder');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'folder_id': folderId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> renameFolder(int folderId, String name) async {
    final url = Uri.parse('$baseUrl/vocab/rename_folder');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'folder_id': folderId, 'name': name}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '網路連線失敗'};
    }
  }

  static Future<List<Map<String, dynamic>>> getScenes({bool quickSelect = false}) async {
    final uri = Uri.parse('$baseUrl/scenario/scenes').replace(queryParameters: quickSelect ? {'quick_select': 'true'} : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) return (json.decode(response.body) as List).cast<Map<String, dynamic>>();
    return [];
  }

  static Future<List<dynamic>> getUnlockedScenes(int userId, {int limit = 3}) async {
    final url = Uri.parse('$baseUrl/scenario/unlocked/$userId?limit=$limit');
    final response = await http.get(url);
    if (response.statusCode == 200) return json.decode(response.body)['scenes'];
    throw Exception('無法載入');
  }

  static Future<List<dynamic>> getSceneVocabs(int sceneId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/scene/$sceneId?user_id=$userId');
    final response = await http.get(url);
    if (response.statusCode == 200) return json.decode(response.body)['vocabs'];
    throw Exception('無法載入');
  }

  static Future<List<dynamic>> getVocabsByPhoto(String imagePath, int userId) async {
    final url = Uri.parse('$baseUrl/scenario/photo_vocabs?user_id=$userId&image_path=${Uri.encodeComponent(imagePath)}');
    final response = await http.get(url);
    if (response.statusCode == 200) return json.decode(response.body)['vocabs'];
    throw Exception('無法載入');
  }

  static Future<Map<String, dynamic>> getVocabDetail(int vocabId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/detail/$vocabId?user_id=$userId');
    final response = await http.get(url);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('無法載入');
  }

  static Future<bool> toggleFavorite(int vocabId, int userId) async {
    final url = Uri.parse('$baseUrl/vocab/collect');
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: json.encode({'user_id': userId, 'vocab_id': vocabId}));
    return response.statusCode == 201;
  }

  // ==========================================
  // 🤖 其他 AI 與測驗功能
  // ==========================================

  static Future<List<dynamic>> fetchQuizQuestions() async {
    final url = Uri.parse('$baseUrl/quiz/questions');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body)['questions'] ?? [];
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> submitQuizResults(int userId, List<bool> results) async {
    final url = Uri.parse('$baseUrl/quiz/submit');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'results': results}));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '伺服器錯誤'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> submitQuizScore(int userId, int score) async {
    final url = Uri.parse('$baseUrl/quiz/submit');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'score': score}));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '請求失敗'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> analyzeImage(String imagePath, int userId, {String? customTitle}) async {
    final url = Uri.parse('$baseUrl/scenario/analyze');
    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['user_id'] = userId.toString();
      if (customTitle != null && customTitle.isNotEmpty) request.fields['custom_title'] = customTitle;

      if (kIsWeb) {
        final imageResponse = await http.get(Uri.parse(imagePath));
        request.files.add(http.MultipartFile.fromBytes('image', imageResponse.bodyBytes, filename: 'web_image.jpg'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if ([200, 400, 500].contains(response.statusCode)) return jsonDecode(response.body);
      return {'error': '伺服器錯誤'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> renamePhoto(int photoId, String customTitle) async {
    final url = Uri.parse('$baseUrl/scenario/rename_photo');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'photo_id': photoId, 'custom_title': customTitle}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> claimReward(int groupId, int userId) async {
    final url = Uri.parse('$baseUrl/group/claim_reward');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'group_id': groupId, 'user_id': userId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> askTutorQuestion(String question) async {
    final url = Uri.parse('$baseUrl/tutor/ask');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'question': question}));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '後端錯誤'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  // ==========================================
  // 訂閱系統 API
  // ==========================================

  static Future<Map<String, dynamic>> getSubscriptionPlans() async {
    final url = Uri.parse('$baseUrl/subscription/plans');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '無法取得'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getSubscriptionStatus(int userId) async {
    final url = Uri.parse('$baseUrl/subscription/status/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '無法取得'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> subscribeplan({required int userId, required int planId, required String billingCycle, required String paymentMethod}) async {
    final url = Uri.parse('$baseUrl/subscription/subscribe');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'plan_id': planId, 'billing_cycle': billingCycle, 'payment_method': paymentMethod}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> cancelSubscription(int userId) async {
    final url = Uri.parse('$baseUrl/subscription/cancel/$userId');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> scheduleYearlyUpgrade(int userId, {String paymentMethod = 'google_pay'}) async {
    final url = Uri.parse('$baseUrl/subscription/schedule_upgrade');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'payment_method': paymentMethod}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> payPendingUpgrade(int userId, {String paymentMethod = 'google_pay'}) async {
    final url = Uri.parse('$baseUrl/subscription/pay_pending');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'payment_method': paymentMethod}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> cancelScheduleUpgrade(int userId) async {
    final url = Uri.parse('$baseUrl/subscription/schedule_upgrade/$userId');
    try {
      final response = await http.delete(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> spendPoints({required int userId, required int points, required String feature}) async {
    final url = Uri.parse('$baseUrl/user/spend_points');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'points': points, 'feature': feature}));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {...data, '_status': response.statusCode};
    } catch (e) {
      return {'error': '[debug] $e', '_status': 0};
    }
  }

  static Future<Map<String, dynamic>> incrementScan(int userId) async {
    final url = Uri.parse('$baseUrl/user/increment_scan');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId}));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {...data, '_status': response.statusCode};
    } catch (e) {
      return {'error': '連線失敗', '_status': 0};
    }
  }

  static Future<Map<String, dynamic>> getPointPackages() async {
    final url = Uri.parse('$baseUrl/store/packages');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '無法取得'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> getStoreItems() async {
    final url = Uri.parse('$baseUrl/store/items');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'error': '無法取得'};
    } catch (e) {
      return {'error': '連線失敗'};
    }
  }

  static Future<Map<String, dynamic>> useAI(int userId) async {
    final url = Uri.parse('$baseUrl/user/use_ai');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId}));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {...data, '_status': response.statusCode};
    } catch (e) {
      return {'error': '連線失敗', '_status': 0};
    }
  }

  // ==========================================
  // 🌟 文章錄音與 AI 評分 API (超級除錯版)
  // ==========================================

  static Future<Map<String, dynamic>> evaluateArticleAudio(String audioPath, String articleText) async {
    final url = Uri.parse('$baseUrl/articles/evaluate');
    try {
      debugPrint('🟢 [進度 1] 準備發送錄音... API 網址: $url');
      debugPrint('🟢 [進度 2] 錄音檔位置: $audioPath');

      var request = http.MultipartRequest('POST', url);
      request.fields['article_text'] = articleText;

      if (kIsWeb) {
        debugPrint('🟢 [進度 3] Web 模式：正在讀取虛擬錄音檔...');
        // 加上 10 秒超時，避免網頁讀取 Blob 遇到死結
        final audioResponse = await http.get(Uri.parse(audioPath)).timeout(const Duration(seconds: 10));
        final bytes = audioResponse.bodyBytes;
        
        debugPrint('🟢 [進度 4] 檔案讀取成功！大小為: ${bytes.length} bytes');
        request.files.add(http.MultipartFile.fromBytes('audio', bytes, filename: 'web_audio.m4a'));
      } else {
        debugPrint('🟢 [進度 3] 手機模式：正在讀取實體檔案...');
        request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
        debugPrint('🟢 [進度 4] 手機檔案載入完畢！');
      }

      debugPrint('🟢 [進度 5] 正在將檔案與標準文字上傳至 Flask 後端...');
      // 加上 30 秒超時，避免網路不穩時無限期卡死轉圈圈
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('🟢 [進度 6] 後端處理完畢！狀態碼: ${response.statusCode}');
      final String responseBody = utf8.decode(response.bodyBytes);
      return jsonDecode(responseBody);
      
    } catch (e) {
      debugPrint('❌ [發生錯誤] 錄音上傳失敗: $e');
      // 捕捉到錯誤後回傳，讓 UI 停止轉圈圈並顯示錯誤提示
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
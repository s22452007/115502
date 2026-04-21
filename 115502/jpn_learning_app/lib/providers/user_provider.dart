import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  int? _userId;
  String _japaneseLevel = '';
  String? _email;
  String? _username;
  String? _avatar;

  // 連續天數與點數
  int _streakDays = 0;
  int _jPts = 0;
  String? _friendId;

  // 存放今日進度
  int _dailyScans = 0;
  int get dailyScans => _dailyScans;

  // 存放待確認的好友邀請數量
  int _pendingFriendRequests = 0;
  int get pendingFriendRequests => _pendingFriendRequests;

  // ==========================================
  // --- ✅ 登入狀態 ---
  // ==========================================
  bool get isLoggedIn => _userId != null;

  // ==========================================
  // --- 🏆 徽章系統狀態 ---
  // ==========================================
  Map<String, int> _badgeProgress = {};
  Map<String, int> get badgeProgress => _badgeProgress;

  void setBadgeProgress(Map<String, dynamic> progressData) {
    _badgeProgress = progressData.map((key, value) {
      return MapEntry(key, value is int ? value : (value as num).toInt());
    });
    notifyListeners();
  }

  // ==========================================
  // --- 基本資料 getter ---
  // ==========================================
  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;
  String? get email => _email;
  String? get username => _username;
  String? get avatar => _avatar;
  String? get friendId => _friendId;
  int get streakDays => _streakDays;
  int get jPts => _jPts;

  // ==========================================
  // --- 基本資料 setter ---
  // ==========================================
  void setPendingFriendRequests(int count) {
    _pendingFriendRequests = count;
    notifyListeners();
  }

  void setDailyScans(int scans) {
    _dailyScans = scans;
    notifyListeners();
  }

  void setUserId(int? id) {
    _userId = id;
    notifyListeners();
  }

  void setJapaneseLevel(String level) {
    _japaneseLevel = level;
    notifyListeners();
  }

  void setEmail(String? email) {
    _email = email;
    notifyListeners();
  }

  void setUsername(String? username) {
    _username = username;
    notifyListeners();
  }

  void setAvatar(String? avatar) {
    _avatar = avatar;
    notifyListeners();
  }

  void setStreakDays(int days) {
    _streakDays = days;
    notifyListeners();
  }

  void setJPts(int pts) {
    _jPts = pts;
    notifyListeners();
  }

  void setFriendId(String? id) {
    _friendId = id;
    notifyListeners();
  }

  // ==========================================
  // --- ✅ 一次設定登入者資料（推薦）---
  // ==========================================
  void setLoginUser({
    required int userId,
    String? email,
    String? username,
    String? avatar,
    String japaneseLevel = '',
    int streakDays = 0,
    int jPts = 0,
    String? friendId,
    int dailyScans = 0,
    int pendingFriendRequests = 0,
    Map<String, int>? badgeProgress,
  }) {
    _userId = userId;
    _email = email;
    _username = username;
    _avatar = avatar;
    _japaneseLevel = japaneseLevel;
    _streakDays = streakDays;
    _jPts = jPts;
    _friendId = friendId;
    _dailyScans = dailyScans;
    _pendingFriendRequests = pendingFriendRequests;
    _badgeProgress = badgeProgress ?? {};
    notifyListeners();
  }

  // ==========================================
  // --- 登出 ---
  // ==========================================
  void logout() {
    _userId = null;
    _email = null;
    _username = null;
    _japaneseLevel = '';
    _avatar = null;
    _streakDays = 0;
    _jPts = 0;
    _friendId = null;
    _dailyScans = 0;
    _pendingFriendRequests = 0;
    _badgeProgress = {};
    notifyListeners();
  }
}
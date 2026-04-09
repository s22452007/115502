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
  
  // 讓外面可以讀取這個數量
  int get pendingFriendRequests => _pendingFriendRequests;

  // 設定數量的方法 (當後端告訴我們有新邀請時呼叫)
  void setPendingFriendRequests(int count) {
    _pendingFriendRequests = count;
    notifyListeners();
  }

  // ==========================================
  // --- 🏆 徽章系統狀態 ---
  // ==========================================
  
  // 存放真實的 5 大核心徽章進度
  Map<String, int> _badgeProgress = {};
  Map<String, int> get badgeProgress => _badgeProgress;

  // 設定真實徽章進度的方法
  void setBadgeProgress(Map<String, dynamic> progressData) {
    _badgeProgress = progressData.map((key, value) {
      return MapEntry(key, value is int ? value : (value as num).toInt());
    });
    notifyListeners(); 
  }

  // ==========================================
  // --- 基本資料設定方法 ---
  // ==========================================

  // 設定今日進度的方法
  void setDailyScans(int scans) {
    _dailyScans = scans;
    notifyListeners();
  }

  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;
  String? get email => _email;
  String? get username => _username;
  String? get avatar => _avatar;
  String? get friendId => _friendId;

  // 取得天數與點數
  int get streakDays => _streakDays;
  int get jPts => _jPts;

  void setUserId(int id) {
    _userId = id;
    notifyListeners();
  }

  void setJapaneseLevel(String level) {
    _japaneseLevel = level;
    notifyListeners();
  }

  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void setUsername(String? username) {
    _username = username;
    notifyListeners();
  }

  // 設定大頭貼的方法
  void setAvatar(String? avatar) {
    _avatar = avatar;
    notifyListeners();
  }

  // 設定天數的方法
  void setStreakDays(int days) {
    _streakDays = days;
    notifyListeners();
  }

  void setJPts(int pts) {
    _jPts = pts;
    notifyListeners();
  }

  void setFriendId(String id) {
    _friendId = id;
    notifyListeners();
  }

  // ==========================================
  // --- 登出 ---
  // ==========================================

  // 登出方法，清空所有資料
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
    
    // 清空徽章資料
    _badgeProgress = {}; 
    
    notifyListeners(); 
  }
}
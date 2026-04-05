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

  // --- 🏆 徽章系統狀態 ---
  // 存放已解鎖的徽章 ID (預設先放入兩個作為測試)
  List<String> _unlockedBadgeIds = ['food_01', 'novice_01'];
  List<String> get unlockedBadgeIds => _unlockedBadgeIds;

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

  // 設定點數的方法
  void setJPts(int pts) {
    _jPts = pts;
    notifyListeners();
  }

  // 新增 set 方法
  void setFriendId(String id) {
    _friendId = id;
    notifyListeners();
  }

  // --- 🏆 徽章系統相關方法 ---

  // 從後端取得資料後，整批設定已解鎖徽章
  void setUnlockedBadges(List<String> badgeIds) {
    _unlockedBadgeIds = badgeIds;
    notifyListeners();
  }

  // 檢查特定徽章是否已解鎖
  bool isBadgeUnlocked(String badgeId) {
    return _unlockedBadgeIds.contains(badgeId);
  }

  // 解鎖單一新徽章
  void unlockBadge(String badgeId) {
    if (!_unlockedBadgeIds.contains(badgeId)) {
      _unlockedBadgeIds.add(badgeId);
      notifyListeners(); // 通知所有畫面更新徽章狀態
    }
  }

  // 為了新版徽章 UI 暫時加的假資料方法 (未來再串接真實資料)
  String? getBadgeUnlockDate(String badgeId) {
    // 假設如果是已解鎖的，就回傳今天日期
    if (isBadgeUnlocked(badgeId)) {
      return '2026.04.05'; 
    }
    return null;
  }

  List<int> getBadgeProgress(String badgeId) {
    // 隨便給個進度里程碑讓畫面有東西畫
    return [10, 50, 100]; 
  }

  // 登出方法，清空所有資料
  void logout() {
    _userId = null;
    _email = null;
    _username = null;
    _japaneseLevel = '';
    _avatar = null;
    _streakDays = 0; // 登出時歸零
    _jPts = 0;       // 登出時歸零
    _friendId = null; // 登出時清空
    _dailyScans = 0;
    _unlockedBadgeIds = []; // 登出時清空徽章資料
    _pendingFriendRequests = 0;
    notifyListeners(); // 通知所有畫面「這個人已經登出了，請更新畫面！」
  }
}
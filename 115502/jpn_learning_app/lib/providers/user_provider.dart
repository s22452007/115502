import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  int? _userId;
  String _japaneseLevel = '';
  String? _email;
  String? _username;
  String? _avatar;

  int _streakDays = 0;
  int _jPts = 0;
  String? _friendId;

  int _dailyScans = 0;
  int get dailyScans => _dailyScans;

  int _pendingFriendRequests = 0;
  int get pendingFriendRequests => _pendingFriendRequests;

  bool get isLoggedIn => _userId != null;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _trialUsed = false;
  bool get trialUsed => _trialUsed;

  // 訂閱詳細狀態
  String? _subscriptionEndDate;
  bool _autoRenew = false;
  String? _subscriptionStatus;
  String? _subscriptionPlanName;
  String? _billingCycle;

  String? get subscriptionEndDate => _subscriptionEndDate;
  bool get autoRenew => _autoRenew;
  String? get subscriptionStatus => _subscriptionStatus;
  String? get subscriptionPlanName => _subscriptionPlanName;
  String? get billingCycle => _billingCycle;

  // 使用量追蹤
  int _photoCountToday = 0;
  int _photoExtraCount = 0;
  int _aiCountToday = 0;
  int _aiExtraCount = 0;
  int _vocabSlot = 50;

  int get photoCountToday => _photoCountToday;
  int get photoExtraCount => _photoExtraCount;
  int get aiCountToday => _aiCountToday;
  int get aiExtraCount => _aiExtraCount;
  int get vocabSlot => _vocabSlot;

  int get photoDailyLimit => _isPremium ? 10 : 2;
  int get aiDailyLimit => _isPremium ? 10 : 3;

  void setUsageStatus({
    int photoCountToday = 0,
    int photoExtraCount = 0,
    int aiCountToday = 0,
    int aiExtraCount = 0,
    int vocabSlot = 50,
  }) {
    _photoCountToday = photoCountToday;
    _photoExtraCount = photoExtraCount;
    _aiCountToday = aiCountToday;
    _aiExtraCount = aiExtraCount;
    _vocabSlot = vocabSlot;
    notifyListeners();
  }

  void updatePhotoUsage({int? countToday, int? extraCount}) {
    if (countToday != null) _photoCountToday = countToday;
    if (extraCount != null) _photoExtraCount = extraCount;
    notifyListeners();
  }

  void updateAIUsage({int? countToday, int? extraCount}) {
    if (countToday != null) _aiCountToday = countToday;
    if (extraCount != null) _aiExtraCount = extraCount;
    notifyListeners();
  }

  bool get hasActiveSubscription {
    if (!_isPremium) return false;
    if (_subscriptionEndDate == null) return false;
    return DateTime.tryParse(_subscriptionEndDate!)?.isAfter(DateTime.now()) ?? false;
  }

  void setSubscriptionInfo({
    String? endDate,
    bool autoRenew = false,
    String? status,
    String? planName,
    String? billingCycle,
  }) {
    _subscriptionEndDate = endDate;
    _autoRenew = autoRenew;
    _subscriptionStatus = status;
    _subscriptionPlanName = planName;
    _billingCycle = billingCycle;
    notifyListeners();
  }

  Map<String, int> _badgeProgress = {};
  Map<String, int> get badgeProgress => _badgeProgress;

  void setBadgeProgress(Map<String, dynamic> progressData) {
    _badgeProgress = progressData.map((key, value) {
      return MapEntry(key, value is int ? value : (value as num).toInt());
    });
    notifyListeners();
  }

  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;
  String? get email => _email;
  String? get username => _username;
  String? get avatar => _avatar;
  String? get friendId => _friendId;
  int get streakDays => _streakDays;
  int get jPts => _jPts;

  void setIsPremium(bool value) { _isPremium = value; notifyListeners(); }
  void setTrialUsed(bool value) { _trialUsed = value; notifyListeners(); }
  void setPendingFriendRequests(int count) { _pendingFriendRequests = count; notifyListeners(); }
  void setDailyScans(int scans) { _dailyScans = scans; notifyListeners(); }
  void setUserId(int? id) { _userId = id; notifyListeners(); }
  void setJapaneseLevel(String level) { _japaneseLevel = level; notifyListeners(); }
  void setEmail(String? email) { _email = email; notifyListeners(); }
  void setUsername(String? username) { _username = username; notifyListeners(); }
  void setAvatar(String? avatar) { _avatar = avatar; notifyListeners(); }
  void setStreakDays(int days) { _streakDays = days; notifyListeners(); }
  void setFriendId(String? id) { _friendId = id; notifyListeners(); }

  // 確保點數更新方法名稱一致
  void setJPts(int pts) {
    _jPts = pts;
    notifyListeners();
  }

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
    bool isPremium = false,
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
    _isPremium = isPremium;
    notifyListeners();
  }

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
    _isPremium = false;
    _trialUsed = false;
    _subscriptionEndDate = null;
    _autoRenew = false;
    _subscriptionStatus = null;
    _subscriptionPlanName = null;
    _billingCycle = null;
    _photoCountToday = 0;
    _photoExtraCount = 0;
    _aiCountToday = 0;
    _aiExtraCount = 0;
    _vocabSlot = 50;
    notifyListeners();
  }
}
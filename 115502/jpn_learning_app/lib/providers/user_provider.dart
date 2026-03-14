import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  int? _userId;
  String _japaneseLevel = '';
  String? _email;
  String? _avatar;

  // 連續天數與點數
  int _streakDays = 0;
  int _jPts = 0;

  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;
  String? get email => _email;
  String? get avatar => _avatar;

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

  // 登出方法，清空所有資料
  void logout() {
    _userId = null;
    _email = null;
    _japaneseLevel = ''; 
    _avatar = null;
    _streakDays = 0; // 登出時歸零
    _jPts = 0;       // 登出時歸零
    notifyListeners(); // 通知所有畫面「這個人已經登出了，請更新畫面！」
  }
}
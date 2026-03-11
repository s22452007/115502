import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  int? _userId;
  String _japaneseLevel = '';
  String? _email;
  String? _avatar;

  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;
  String? get email => _email;
  String? get avatar => _avatar;

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

  // 新增設定大頭貼的方法
  void setAvatar(String? avatar) {
    _avatar = avatar;
    notifyListeners();
  }
}
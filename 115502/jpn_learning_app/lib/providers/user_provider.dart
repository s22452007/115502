import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  int? _userId; // 新增：儲存使用者的專屬 ID
  String _japaneseLevel = '';

  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;

  // 登入或註冊成功時，把後端給的 ID 存起來
  void setUserId(int id) {
    _userId = id;
    notifyListeners();
  }

  void setJapaneseLevel(String level) {
    _japaneseLevel = level;
    notifyListeners();
  }
}
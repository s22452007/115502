import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  int? _userId;
  String _japaneseLevel = '';
  String? _email;

  int? get userId => _userId;
  String get japaneseLevel => _japaneseLevel;
  String? get email => _email;

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
}
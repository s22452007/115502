import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  // 儲存使用者的日語程度
  String _japaneseLevel = '';

  // 取得目前的日語程度
  String get japaneseLevel => _japaneseLevel;

  // 更新日語程度，並通知有使用到這個變數的畫面進行刷新
  void setJapaneseLevel(String level) {
    _japaneseLevel = level;
    notifyListeners();
  }

  // TODO: 未來可以在這裡擴充更多使用者相關的狀態，例如學習進度、代幣數量等
}
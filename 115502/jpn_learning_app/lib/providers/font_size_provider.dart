import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeProvider extends ChangeNotifier {
  double _scale = 1.0;
  double get scale => _scale;

  static const _key = 'font_size_scale';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _scale = (prefs.getDouble(_key) ?? 1.0).clamp(0.85, 1.3);
    notifyListeners();
  }

  Future<void> setScale(double value) async {
    _scale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
  }
}

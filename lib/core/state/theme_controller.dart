import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }
  static const _key = 'homes_theme_mode';
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  Future<void> _load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    _mode = ThemeMode.values.where((item) => item.name == value).firstOrNull ??
        ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    _mode = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

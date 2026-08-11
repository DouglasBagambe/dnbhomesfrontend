import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompareController extends ChangeNotifier {
  CompareController() {
    _load();
  }
  static const _key = 'homes_compare_v1';
  final List<String> _ids = [];
  List<String> get ids => List.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);
  bool get canAdd => _ids.length < 2;
  Future<void> _load() async {
    _ids.addAll(
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [],
    );
    if (_ids.length > 2) _ids.removeRange(2, _ids.length);
    notifyListeners();
  }

  Future<bool> toggle(String id) async {
    if (_ids.contains(id))
      _ids.remove(id);
    else {
      if (!canAdd) return false;
      _ids.add(id);
    }
    notifyListeners();
    await (await SharedPreferences.getInstance()).setStringList(_key, _ids);
    return true;
  }

  Future<void> clear() async {
    _ids.clear();
    notifyListeners();
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}

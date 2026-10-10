import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompareController extends ChangeNotifier {
  CompareController() {
    ready = _load();
  }
  late final Future<void> ready;
  Future<void> Function(String, bool)? onSelection;
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
    await ready;
    if (_ids.contains(id))
      _ids.remove(id);
    else {
      if (!canAdd) return false;
      _ids.add(id);
    }
    notifyListeners();
    await (await SharedPreferences.getInstance()).setStringList(_key, _ids);
    await onSelection?.call(id, _ids.contains(id));
    return true;
  }

  Future<void> replaceIds(Iterable<String> ids) async {
    await ready;
    _ids
      ..clear()
      ..addAll(ids.toSet().take(2));
    await (await SharedPreferences.getInstance()).setStringList(_key, _ids);
    notifyListeners();
  }

  Future<void> clear() async {
    await ready;
    final removed = List<String>.of(_ids);
    _ids.clear();
    notifyListeners();
    await (await SharedPreferences.getInstance()).remove(_key);
    for (final id in removed) {
      await onSelection?.call(id, false);
    }
  }
}

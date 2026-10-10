import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController() {
    ready = _load();
  }
  late final Future<void> ready;
  Future<void> Function(String, bool)? onSelection;
  static const _key = 'homes_favorites_v1';
  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);
  Future<void> _load() async {
    _ids.addAll(
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [],
    );
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    await ready;
    _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
    notifyListeners();
    await (await SharedPreferences.getInstance()).setStringList(
      _key,
      _ids.toList(),
    );
    await onSelection?.call(id, _ids.contains(id));
  }

  Future<void> replaceIds(Iterable<String> ids) async {
    await ready;
    _ids
      ..clear()
      ..addAll(ids);
    await (await SharedPreferences.getInstance())
        .setStringList(_key, _ids.toList());
    notifyListeners();
  }

  Future<void> clear() async {
    _ids.clear();
    notifyListeners();
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}

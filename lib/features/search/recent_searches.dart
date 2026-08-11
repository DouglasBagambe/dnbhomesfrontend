import 'package:shared_preferences/shared_preferences.dart';

class RecentSearches {
  static const _key = 'homes_recent_searches_v1';
  Future<List<String>> getAll() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
  Future<void> add(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    final items = await getAll();
    items.removeWhere((item) => item.toLowerCase() == text.toLowerCase());
    items.insert(0, text);
    await (await SharedPreferences.getInstance()).setStringList(
      _key,
      items.take(6).toList(),
    );
  }

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/bookings_repository.dart';

class BookingsController extends ChangeNotifier {
  BookingsController() {
    ready = _load();
  }
  late final Future<void> ready;
  static const _key = 'homes_viewing_requests_v1';
  final List<ViewingRequest> _items = [];
  List<ViewingRequest> get items => List.unmodifiable(_items);
  bool refreshing = false;
  String? feedback;
  DateTime? lastRefreshed;
  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw != null) {
      try {
        _items.addAll((jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .map(ViewingRequest.fromJson));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final minimized = _items
        .map((entry) => {...entry.toJson(), 'guestEmail': '', 'guestPhone': ''})
        .toList();
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(minimized));
  }

  Future<void> add(ViewingRequest item) async {
    await ready;
    _items.insert(0, item);
    notifyListeners();
    await _persist();
  }

  Future<void> refresh(BookingsRepository repo) async {
    if (refreshing) return;
    refreshing = true;
    feedback = null;
    notifyListeners();
    await ready;
    var updated = 0, failed = 0, legacy = 0;
    try {
      for (final item in List<ViewingRequest>.of(_items)) {
        if (!item.canSync) {
          legacy++;
          continue;
        }
        try {
          final fresh = await repo.refresh(item);
          final index = _items.indexWhere((entry) => entry.id == item.id);
          if (index >= 0) _items[index] = fresh;
          updated++;
        } catch (_) {
          failed++;
        }
      }
      await _persist();
      if (updated > 0) lastRefreshed = DateTime.now();
      feedback =
          '${updated > 0 ? "$updated requests refreshed." : "No live status updates."}${failed > 0 ? " $failed unavailable; saved copies kept. Try again." : ""}${legacy > 0 ? " $legacy older requests cannot sync." : ""}';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }
}

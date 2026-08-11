import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/bookings_repository.dart';

class BookingsController extends ChangeNotifier {
  BookingsController() {
    _load();
  }
  static const _key = 'homes_viewing_requests_v1';
  final List<ViewingRequest> _items = [];
  List<ViewingRequest> get items => List.unmodifiable(_items);
  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw != null) {
      try {
        _items.addAll(
          (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(
                ViewingRequest.fromJson,
              ),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> add(ViewingRequest item) async {
    _items.insert(0, item);
    notifyListeners();
    final minimized = _items
        .map(
          (entry) => {
            'id': entry.id,
            'reference': entry.reference,
            'propertyId': entry.propertyId,
            'scheduledAt': entry.scheduledAt.toIso8601String(),
            'status': entry.status,
            'guestName': entry.guestName,
            'guestEmail': '',
            'guestPhone': '',
          },
        )
        .toList();
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(minimized),
    );
  }
}

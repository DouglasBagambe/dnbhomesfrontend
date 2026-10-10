import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../favorites/favorites_controller.dart';
import '../compare/compare_controller.dart';
import '../bookings/bookings_controller.dart';
import '../bookings/data/bookings_repository.dart';

abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureSessionStore implements SessionStore {
  final storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device));
  static const key = 'homes_consumer_session_v1';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete() => storage.delete(key: key);
}

class ConsumerProfile {
  const ConsumerProfile(
      {required this.id,
      required this.name,
      required this.email,
      required this.phone});
  final String id, name, email, phone;
  factory ConsumerProfile.fromJson(Map<String, dynamic> value) =>
      ConsumerProfile(
          id: value['id'] as String,
          name: value['name'] as String,
          email: value['email'] as String,
          phone: value['phone'] as String? ?? '');
}

class ConsumerController extends ChangeNotifier {
  ConsumerController(this.api, this.favorites, this.compare, this.bookings,
      {SessionStore? sessionStore})
      : sessionStore = sessionStore ?? SecureSessionStore() {
    api.consumerToken = () async => _token;
    api.onConsumerToken = (value) async {
      await this.sessionStore.write(value);
      _token = value;
    };
    api.onConsumerExpired = expire;
    favorites.onSelection = (id, active) => selection('saved', id, active);
    compare.onSelection = (id, active) => selection('compare', id, active);
    ready = _load();
  }
  final ApiClient api;
  final FavoritesController favorites;
  final CompareController compare;
  final BookingsController bookings;
  final SessionStore sessionStore;
  late final Future<void> ready;
  ConsumerProfile? user;
  String? _token, feedback;
  bool loading = true, syncing = false;
  bool viewingUpdates = true;
  List<ViewingRequest> viewings = [];
  int _viewingPage = 0;
  bool hasMoreViewings = false;
  List<String> recent = [];
  Future<void> _queue = Future.value();
  Future<void> _persistQueue = Future.value();
  int _revision = 0;
  Future<void>? _refreshing;
  int _epoch = 0;
  bool _disposed = false;
  bool get signedIn => user != null;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _load() async {
    await Future.wait([favorites.ready, compare.ready, bookings.ready]);
    try {
      _token = await sessionStore.read();
      if (_token != null)
        await refresh();
      else if ((await SharedPreferences.getInstance())
          .containsKey('homes_active_consumer')) await _restoreGuest();
    } catch (_) {
      feedback =
          'Account connection unavailable. Your local selections are kept.';
    }
    loading = false;
    changed();
  }

  Future<void> auth(String action, Map<String, dynamic> body) async {
    await api.postJson('/auth/consumer/$action', body);
    if (_token != null &&
        ['sign-in/email', 'email-otp/verify-email'].contains(action))
      await refresh();
  }

  Future<void> refresh() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    if (_token == null) return;
    final generation = _epoch;
    syncing = true;
    changed();
    try {
      final response = await api.getJson('/consumer/me');
      if (generation != _epoch) return;
      final profile =
          ConsumerProfile.fromJson(response['data'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString('homes_active_consumer');
      final changedOwner = user?.id != profile.id;
      if (changedOwner && previous != profile.id) {
        if (previous != null) await _restoreGuest();
        await prefs.setStringList('homes_guest_saved', favorites.ids.toList());
        await prefs.setStringList('homes_guest_compare', compare.ids);
      }
      user = profile;
      await prefs.setString('homes_active_consumer', profile.id);
      if (changedOwner)
        await api.postJson('/consumer/merge', {
          'saved': prefs.getStringList('homes_guest_saved') ?? [],
          'compare': prefs.getStringList('homes_guest_compare') ?? [],
          'recent': prefs.getStringList('homes_guest_recent') ?? [],
          'viewings': bookings.items
              .where((v) => v.canSync)
              .take(30)
              .map((v) => {'id': v.id, 'token': v.statusAccessToken})
              .toList(),
        });
      await _queue;
      await _flush();
      final expectedRevision = _revision;
      final state = (await api.getJson('/consumer/state'))['data']
          as Map<String, dynamic>;
      if (generation != _epoch || expectedRevision != _revision) return;
      await favorites.replaceIds((state['saved'] as List).cast<String>());
      await compare.replaceIds((state['compare'] as List).cast<String>());
      recent = (state['recent'] as List).cast<String>();
      viewingUpdates =
          (state['notifications'] as Map?)?['viewingUpdates'] != false;
      await refreshViewings();
      feedback = null;
    } on ApiFailure catch (error) {
      feedback = error.message;
    } finally {
      syncing = false;
      loading = false;
      changed();
    }
  }

  Future<void> refreshViewings({bool append = false}) async {
    if (user == null) return;
    final generation = _epoch;
    final page = append ? _viewingPage + 1 : 1;
    final result =
        await api.getJson('/consumer/viewings', query: {'page': '$page'});
    if (generation != _epoch) return;
    final incoming =
        (result['data'] as List).cast<Map<String, dynamic>>().map((value) {
      final property = value['property'] as Map?;
      return ViewingRequest.fromJson({
        ...value,
        'propertyId': property?['_id'] ?? '',
        'propertyTitle': property?['title'] ?? 'Property no longer available',
        'guestName': '',
        'guestEmail': '',
        'guestPhone': ''
      });
    }).toList();
    _viewingPage = page;
    hasMoreViewings =
        page < ((result['pagination'] as Map?)?['pages'] as int? ?? 0);
    viewings = append
        ? [
            ...viewings,
            ...incoming.where(
                (item) => !viewings.any((existing) => existing.id == item.id))
          ]
        : incoming;
    changed();
  }

  Future<void> selection(
      String collection, String propertyId, bool active) async {
    if (user == null) return;
    final owner = user!.id;
    _revision++;
    _persistQueue = _persistQueue.then((_) async {
      if (user?.id != owner) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'homes_sync_outbox_$owner';
      final pending = _pending(prefs.getString(key));
      pending.add({
        'id':
            '${DateTime.now().microsecondsSinceEpoch}:$collection:$propertyId',
        'collection': collection,
        'propertyId': propertyId,
        'action': active ? 'add' : 'remove'
      });
      await prefs.setString(key, jsonEncode(pending));
    });
    await _persistQueue;
    _queue = _queue.then((_) async {
      if (user?.id != owner) return;
      try {
        await _flush();
        feedback = null;
      } catch (_) {
        feedback =
            'Selection kept on this device. Sync will retry when connected.';
      }
      changed();
    });
    // Saving responds immediately; network serialization is background work.
  }

  List<Map<String, dynamic>> _pending(String? value) {
    try {
      return (jsonDecode(value ?? '[]') as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _flush() async {
    final owner = user?.id;
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'homes_sync_outbox_$owner';
    for (final operation in _pending(prefs.getString(key))) {
      if (user?.id != owner) return;
      await api.postJson('/consumer/state', operation);
      final next = _pending(prefs.getString(key))
        ..removeWhere((item) => item['id'] == operation['id']);
      await prefs.setString(key, jsonEncode(next));
    }
  }

  Future<void> recordRecent(String id) async {
    if (user != null) {
      recent = [id, ...recent.where((value) => value != id)].take(30).toList();
      changed();
      await selection('recent', id, true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('homes_guest_recent') ?? [];
    await prefs.setStringList('homes_guest_recent',
        [id, ...values.where((value) => value != id)].take(30).toList());
  }

  Future<void> _restoreGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await favorites.replaceIds(prefs.getStringList('homes_guest_saved') ?? []);
    await compare.replaceIds(prefs.getStringList('homes_guest_compare') ?? []);
    await prefs.remove('homes_active_consumer');
  }

  Future<void> expire() async {
    _epoch++;
    _token = null;
    user = null;
    viewings = [];
    await sessionStore.delete();
    await _restoreGuest();
    changed();
  }

  Future<void> signOut({bool all = false}) async {
    await api
        .postJson('/auth/consumer/${all ? 'revoke-sessions' : 'sign-out'}', {});
    await expire();
    feedback = null;
  }

  Future<void> updateProfile(String name, String phone) async {
    await auth('update-user', {'name': name.trim(), 'phone': phone.trim()});
    await refresh();
  }

  Future<void> deleteAccount(String password) async {
    await auth('delete-user', {'password': password});
    await expire();
  }

  @override
  void dispose() {
    _disposed = true;
    favorites.onSelection = null;
    compare.onSelection = null;
    api.consumerToken = null;
    api.onConsumerToken = null;
    api.onConsumerExpired = null;
    super.dispose();
  }
}

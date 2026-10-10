import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/accounts/consumer_controller.dart';
import 'package:homes/features/bookings/bookings_controller.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/features/favorites/favorites_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySession implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  test(
      'signed header goes to secure session store; guest merge, outbox retry and logout retain correct state',
      () async {
    const first = '507f1f77bcf86cd799439011',
        second = '507f1f77bcf86cd799439012';
    SharedPreferences.setMockInitialValues({
      'homes_favorites_v1': [first]
    });
    final store = MemorySession();
    final saved = <String>[];
    bool offline = false, revoked = false;
    final requests = <http.Request>[];
    final api = ApiClient(
        baseUrl: 'https://isolated.example.invalid/api/v1',
        client: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/sign-up/email'))
            return http.Response(
                jsonEncode({'token': 'raw-body-token-must-not-be-used'}), 200);
          if (path.endsWith('/sign-in/email'))
            return http.Response(
                jsonEncode({'token': 'ignored-unsigned-body-token'}), 200,
                headers: {'set-auth-token': 'private-session.signed-header'});
          if (path.contains('/auth/consumer/')) return http.Response('{}', 200);
          if (path.endsWith('/me'))
            return http.Response(
                jsonEncode(revoked
                    ? {'message': 'Session expired'}
                    : {
                        'data': {
                          'id': 'consumer-qa',
                          'name': 'QA Consumer',
                          'email': 'qa@example.com',
                          'phone': '+256700000000'
                        }
                      }),
                revoked ? 401 : 200);
          if (path.endsWith('/merge')) {
            final data = jsonDecode(request.body);
            saved.addAll((data['saved'] as List).cast<String>());
          }
          if (path.endsWith('/state') && request.method == 'POST') {
            if (offline)
              return http.Response('{"error":{"message":"QA offline"}}', 503);
            final data = jsonDecode(request.body);
            if (data['action'] == 'remove')
              saved.remove(data['propertyId']);
            else if (!saved.contains(data['propertyId']))
              saved.add(data['propertyId']);
          }
          if (path.endsWith('/viewings')) {
            final page = int.parse(request.url.queryParameters['page'] ?? '1');
            return http.Response(
                jsonEncode({
                  'data': [
                    {
                      '_id': 'viewing-$page',
                      'reference': 'LOCAL-$page',
                      'property': {'_id': first, 'title': 'Owned QA home'},
                      'scheduledAt': '2027-01-01T07:00:00Z',
                      'status': 'confirmed'
                    }
                  ],
                  'pagination': {'page': page, 'pages': 2, 'total': 31}
                }),
                200);
          }
          return http.Response(
              jsonEncode({
                'data': {
                  'saved': saved,
                  'compare': [],
                  'recent': [],
                  'notifications': {
                    'viewingUpdates': true,
                    'searchAlerts': false
                  }
                }
              }),
              200);
        }));
    final favorites = FavoritesController(),
        compare = CompareController(),
        bookings = BookingsController();
    final account = ConsumerController(api, favorites, compare, bookings,
        sessionStore: store);
    await account.ready;
    await account.auth('sign-up/email', {'password': 'isolated test password'});
    expect(store.value, isNull);
    await account.auth('sign-in/email', {});
    expect(store.value, 'private-session.signed-header');
    expect(account.signedIn, isTrue);
    expect(account.viewings.single.propertyTitle, 'Owned QA home');
    expect(account.hasMoreViewings, isTrue);
    await account.refreshViewings(append: true);
    expect(account.viewings.map((item) => item.id), ['viewing-1', 'viewing-2']);
    expect(account.hasMoreViewings, isFalse);
    expect(saved, [first]);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs
            .getKeys()
            .any((key) => key.contains('session') || key.contains('password')),
        isFalse);
    offline = true;
    await favorites.toggle(second);
    await account.refresh();
    expect(favorites.contains(second), isTrue);
    expect(prefs.getString('homes_sync_outbox_consumer-qa'), contains(second));
    offline = false;
    await account.refresh();
    expect(saved.toSet(), {first, second});
    expect(prefs.getString('homes_sync_outbox_consumer-qa'), '[]');
    await api.getJson('/properties');
    expect(requests.last.headers.containsKey('Authorization'), isFalse);
    revoked = true;
    await account.refresh();
    expect(account.signedIn, isFalse);
    expect(store.value, isNull);
    expect(favorites.ids, {first});
    account.dispose();
    favorites.dispose();
    compare.dispose();
    bookings.dispose();
    api.close();
  });
}

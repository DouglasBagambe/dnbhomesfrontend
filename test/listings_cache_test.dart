import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/listings/data/listings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response(int total) => http.Response(
    jsonEncode({
      'data': [],
      'pagination': {'page': 1, 'limit': 20, 'total': total, 'pages': 1}
    }),
    200);

void main() {
  test(
      'repeated public queries coalesce, expire after 30 seconds, and refresh explicitly',
      () async {
    var now = DateTime.utc(2026, 10, 9), calls = 0;
    final gate = Completer<http.Response>();
    final repo = ListingsRepository(
        ApiClient(
            baseUrl: 'https://fixture.example.invalid/api/v1',
            client: MockClient((request) async {
              calls++;
              return calls == 1 ? await gate.future : response(calls);
            })),
        clock: () => now);
    const query = ListingQuery(purpose: 'rent');
    final first = repo.list(query), second = repo.list(query);
    gate.complete(response(1));
    await Future.wait([first, second]);
    expect(calls, 1);
    now = now.add(const Duration(seconds: 29));
    expect((await repo.list(query)).total, 1);
    expect(calls, 1);
    now = now.add(const Duration(seconds: 2));
    expect((await repo.list(query)).total, 2);
    expect((await repo.list(query, refresh: true)).total, 3);
    await repo.list(const ListingQuery(purpose: 'sale'));
    await repo.list(const ListingQuery(purpose: 'rent', page: 2));
    expect(calls, 5);
  });
  test(
      'failures are not cached and refreshing in-flight data cannot be overwritten by an older response',
      () async {
    var calls = 0;
    final old = Completer<http.Response>(), fresh = Completer<http.Response>();
    final repo = ListingsRepository(ApiClient(
        baseUrl: 'https://fixture.example.invalid/api/v1',
        client: MockClient((request) async {
          calls++;
          return switch (calls) {
            1 => http.Response('{}', 503),
            2 => await old.future,
            _ => await fresh.future
          };
        })));
    const query = ListingQuery();
    await expectLater(repo.list(query), throwsA(isA<ApiFailure>()));
    final previous = repo.list(query);
    final refresh = repo.list(query, refresh: true);
    fresh.complete(response(3));
    await refresh;
    old.complete(response(2));
    await previous;
    expect((await repo.list(query)).total, 3);
    expect(calls, 3);
  });
  test('many search queries cannot grow the listing cache without a bound',
      () async {
    var calls = 0;
    final repo = ListingsRepository(ApiClient(
        baseUrl: 'https://fixture.example.invalid/api/v1',
        client: MockClient((request) async {
          calls++;
          return response(calls);
        })));
    for (var i = 0; i < 33; i++) {
      await repo.list(ListingQuery(q: 'area-$i'));
    }
    await repo.list(const ListingQuery(q: 'area-32'));
    expect(calls, 33);
    await repo.list(const ListingQuery(q: 'area-0'));
    expect(calls, 34);
  });
}

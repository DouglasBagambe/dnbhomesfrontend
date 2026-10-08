import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homes/app.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/listings/presentation/property_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const id = '507f1f77bcf86cd799439011';
  const path = '/properties/ntinda-family-home-$id';
  const title = 'Linked Ntinda family home';
  late List<String> requests;
  late ApiClient api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    api = ApiClient(
      baseUrl: 'https://local.example.invalid/api/v1',
      client: MockClient((request) async {
        requests.add(request.url.path);
        final detail = request.url.path == '/api/v1/properties/$id';
        return http.Response(
            jsonEncode({
              'data': detail
                  ? {
                      '_id': id,
                      'slug': 'ntinda-family-home',
                      'title': title,
                      'purpose': 'rent',
                      'type': 'house',
                      'price': {
                        'amount': 1500000,
                        'currency': 'UGX',
                        'period': 'month'
                      },
                      'location': {'country': 'Uganda', 'area': 'Ntinda'},
                      'media': [],
                    }
                  : [],
              'pagination': {'page': 1, 'limit': 20, 'total': 0, 'pages': 0},
            }),
            200);
      }),
    );
  });

  for (final route in [path, 'https://dnbhomes.com$path']) {
    testWidgets('cold launch opens shared property $route', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(HomesApp(apiClient: api));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyDetailScreen), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(requests, contains('/api/v1/properties/$id'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Browse by type'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('warm launch opens a property link and back returns Home',
      (tester) async {
    await tester.pumpWidget(HomesApp(apiClient: api));
    await tester.pumpAndSettle();
    await tester.binding.handlePushRoute(path);
    await tester.pumpAndSettle();
    expect(find.byType(PropertyDetailScreen), findsOneWidget);
    expect(find.text(title), findsOneWidget);
    expect(requests, contains('/api/v1/properties/$id'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(PropertyDetailScreen), findsNothing);
    expect(find.text('Browse by type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

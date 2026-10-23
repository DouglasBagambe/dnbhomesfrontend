import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/app.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/listings/domain/property.dart';
import 'package:homes/features/listings/presentation/property_card.dart';
import 'package:homes/features/listings/presentation/property_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'v2_layout_test.dart' show fixture;

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets(
        '360px Discover grid uses ${scale == 1 ? 'two columns' : 'accessible one column'}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final api = ApiClient(
          baseUrl: 'https://fixture.invalid/api/v1',
          client: MockClient((_) async => http.Response(
              jsonEncode({
                'data': [
                  for (var i = 0; i < 4; i++)
                    {...fixture, '_id': '$i', 'availabilityStatus': 'reserved'}
                ],
                'pagination': {'page': 1, 'pages': 1, 'total': 4}
              }),
              200)));
      await tester.pumpWidget(HomesApp(apiClient: api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      final cards = find.byWidgetPredicate(
          (w) => w is PropertyCard && w.layout == PropertyCardLayout.grid);
      expect(tester.getSize(cards.first).width,
          scale == 1 ? lessThan(170) : greaterThan(300));
      expect(find.text('Swipe'), findsOneWidget);
      await tester.tap(find.text('Swipe'));
      await tester.pumpAndSettle();
      expect(find.text('Grid'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Reserved'))
              .onPressed,
          isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Fresh availability closes viewings even when related recommendations fail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(
        baseUrl: 'https://fixture.invalid/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/properties/test')) {
            return http.Response(
                jsonEncode({
                  'data': {...fixture, 'availabilityStatus': 'reserved'}
                }),
                200);
          }
          return http.Response(
              '{"message":"Recommendations unavailable"}', 503);
        }));
    await tester.pumpWidget(HomesApp(apiClient: api));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute(
        builder: (_) => PropertyDetailScreen(
            idOrSlug: 'test', initial: Property.fromJson(fixture))));
    await tester.pumpAndSettle();
    final action = find.ancestor(
        of: find.text('Reserved · viewings closed'),
        matching: find.byWidgetPredicate((w) => w is FilledButton));
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

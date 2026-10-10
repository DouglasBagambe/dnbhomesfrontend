import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/bookings/bookings_controller.dart';
import 'package:homes/features/bookings/data/bookings_repository.dart';
import 'package:homes/features/listings/presentation/property_card.dart';
import 'package:homes/features/listings/presentation/property_carousel.dart';
import 'package:homes/features/listings/domain/property.dart';
import 'package:homes/features/favorites/favorites_controller.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'v2_layout_test.dart' show fixture;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(600, 960),
    const Size(800, 1280)
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'uniform mixed carousel ${size.width} dark=$dark scale=$scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues(
              {'homes_theme_mode': dark ? 'dark' : 'light'});
          final variations = List.generate(
              4,
              (i) => {
                    ...fixture,
                    '_id': '507f1f77bcf86cd79943901${i + 1}',
                    'title': i == 0
                        ? 'Land'
                        : 'A long property title occupying the supported two lines in a carousel',
                    'type': ['land', 'house', 'apartment', 'commercial'][i],
                    'verificationStatus': i.isEven ? 'verified' : 'unverified',
                    'bedrooms': i.isEven ? 3 : 0,
                    'bathrooms': i == 0 ? 0 : 2,
                    'size': i == 1 ? null : 180
                  });
          await tester.pumpWidget(MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => FavoritesController()),
                ChangeNotifierProvider(create: (_) => CompareController()),
              ],
              child: MaterialApp(
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: Scaffold(
                      body: SingleChildScrollView(
                          child: PropertyCarousel(
                              items: variations.map(Property.fromJson).toList(),
                              onTap: (_) {}))))));
          await tester.pumpAndSettle();
          final cards = find.byWidgetPredicate((w) =>
              w is PropertyCard && w.layout == PropertyCardLayout.horizontal);
          final heights = cards
              .evaluate()
              .take(4)
              .map((e) => tester.getSize(find.byWidget(e.widget)).height)
              .toList();
          expect(heights.length, 4);
          expect(heights.toSet().length, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  test('live statuses persist, legacy is graceful, failures preserve copies',
      () async {
    SharedPreferences.setMockInitialValues({});
    final controller = BookingsController();
    await controller.ready;
    final item = ViewingRequest(
        id: '507f1f77bcf86cd799439011',
        reference: 'HOM-20261010-ABCDEF',
        propertyId: 'property',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        status: 'pending',
        guestName: 'QA',
        guestEmail: '',
        guestPhone: '',
        statusAccessToken: 'a' * 43);
    await controller.add(item);
    String status = 'confirmed';
    bool fail = false;
    final repo = BookingsRepository(ApiClient(
        baseUrl: 'https://fixture.example.invalid/api/v1',
        client: MockClient((r) async {
          expect(r.headers['X-Viewing-Token'], item.statusAccessToken);
          expect(r.url.query, '');
          return http.Response(
              jsonEncode(fail
                  ? {
                      'error': {'message': 'Offline'}
                    }
                  : {
                      'data': {
                        'status': status,
                        'scheduledAt': item.scheduledAt.toIso8601String()
                      }
                    }),
              fail ? 503 : 200);
        })));
    for (final value in [
      'confirmed',
      'rejected',
      'cancelled',
      'completed',
      'no_show'
    ]) {
      status = value;
      await controller.refresh(repo);
      expect(controller.items.first.status, value);
      expect(controller.items.first.isUpcoming, value == 'confirmed');
      final restored = BookingsController();
      await restored.ready;
      expect(restored.items.first.status, value);
      expect(restored.items.first.statusAccessToken, item.statusAccessToken);
      restored.dispose();
    }
    fail = true;
    await controller.refresh(repo);
    expect(controller.items.first.status, 'no_show');
    expect(controller.feedback, contains('saved copies kept'));
    await controller.add(ViewingRequest.fromJson(
        {...item.toJson(), 'id': 'legacy', 'statusAccessToken': null}));
    await controller.refresh(repo);
    expect(controller.feedback, contains('older requests cannot sync'));
    controller.dispose();
  });
}

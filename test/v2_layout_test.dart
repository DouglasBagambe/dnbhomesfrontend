import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/app.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/discover/presentation/filter_sheet.dart';
import 'package:homes/features/listings/data/listings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fixture = <String, dynamic>{
  '_id': '507f1f77bcf86cd799439011',
  'slug': 'family-home',
  'title': 'A bright family home in Ntinda',
  'description': 'Isolated widget fixture.',
  'purpose': 'rent',
  'type': 'house',
  'verificationStatus': 'verified',
  'price': {'amount': 1500000, 'currency': 'UGX', 'period': 'month'},
  'location': {'country': 'Uganda', 'district': 'Kampala', 'area': 'Ntinda'},
  'bedrooms': 3,
  'bathrooms': 2,
  'size': 180,
  'sizeUnit': 'sqm',
  'media': [],
  'amenities': ['Parking', 'Security'],
};
void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(480, 960),
    const Size(600, 960),
    const Size(800, 1280),
    const Size(844, 390),
    const Size(1024, 600)
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('V2 ${size.width}x${size.height} dark=$dark scale=$scale',
            (tester) async {
          SharedPreferences.setMockInitialValues({
            'homes_theme_mode': dark ? 'dark' : 'light',
            'homes_favorites_v1': [fixture['_id']],
            'homes_compare_v1': [fixture['_id'], '507f1f77bcf86cd799439012'],
            'homes_viewing_requests_v1': jsonEncode([
              {
                'id': 'isolated-viewing',
                'reference': 'HOM-TEST-ONLY',
                'propertyId': fixture['_id'],
                'scheduledAt': '2100-10-10T07:00:00.000Z',
                'status': 'pending',
                'guestName': 'Isolated QA',
              }
            ]),
          });
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          await tester.binding.setSurfaceSize(size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() async {
            await tester.binding.setSurfaceSize(null);
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final api = ApiClient(
              baseUrl: 'https://fixture.example.invalid/api/v1',
              client: MockClient((request) async => http.Response(
                  jsonEncode({
                    'data': request.url.path.endsWith('properties')
                        ? [fixture]
                        : fixture,
                    'pagination': {
                      'page': 1,
                      'limit': 20,
                      'total': 1,
                      'pages': 1
                    }
                  }),
                  200)));
          await tester.pumpWidget(HomesApp(apiClient: api));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final destination in ['Discover', 'Saved', 'Viewings', 'Home']) {
            await tester.tap(find.text(destination).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.text('Compare 2 homes'));
          await tester.pumpAndSettle();
          expect(find.text('Two places. A clearer choice.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.binding.handlePushRoute(
              '/properties/family-home-507f1f77bcf86cd799439011');
          await tester.pumpAndSettle();
          expect(find.text('Request a viewing'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Request a viewing'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
      'filters retain district, amenities and hidden query context; reset clears visible fields',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => FilterSheet.show(
                        context,
                        const ListingQuery(
                            q: 'family',
                            district: 'Kampala',
                            area: 'Ntinda',
                            amenities: ['Parking'])),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kampala'), 120,
        scrollable: find
            .descendant(
                of: find.byType(FilterSheet), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Kampala'), findsOneWidget);
    expect(find.text('Ntinda'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.widgetWithText(FilterChip, 'Parking'), 120,
        scrollable: find
            .descendant(
                of: find.byType(FilterSheet), matching: find.byType(Scrollable))
            .first);
    expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Parking'))
            .selected,
        isTrue);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Kampala'), findsNothing);
    expect(find.text('Ntinda'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('applying filters preserves the existing query context',
      (tester) async {
    ListingQuery? result;
    const initial = ListingQuery(
      q: 'family',
      country: 'Uganda',
      region: 'Central',
      district: 'Kampala',
      area: 'Ntinda',
      amenities: ['Parking'],
      featured: true,
      latitude: .3,
      longitude: 32.6,
      radius: 10,
      limit: 12,
      minPrice: 1000,
      maxPrice: 5000,
      bedrooms: 3,
      bathrooms: 2,
      verified: true,
      sort: ListingSort.priceAsc,
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () async {
            result = await FilterSheet.show(context, initial);
          },
          child: const Text('Open')),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(result!.toQuery(), initial.toQuery());
  });
}

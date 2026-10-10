import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/app.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'v2_layout_test.dart' show fixture;

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('Reduced motion keeps property and media navigation working',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    final api = ApiClient(
        baseUrl: 'https://fixture.example.invalid/api/v1',
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'data': List.generate(
                  2,
                  (i) => {
                        ...fixture,
                        '_id': '507f1f77bcf86cd79943901${i + 1}',
                        'title': 'Reduced motion home $i',
                        'media': List.generate(
                            2,
                            (j) => {
                                  'type': 'image',
                                  'url':
                                      'https://fixture.example.invalid/image-$j.jpg',
                                  'alt': 'QA image $j',
                                }),
                      }),
              'pagination': {'page': 1, 'limit': 20, 'total': 2, 'pages': 1},
            }),
            200)));
    await tester.pumpWidget(HomesApp(apiClient: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Swipe').first);
    await tester.tap(find.text('Swipe').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next media'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Next property'));
    await tester.pumpAndSettle();
    expect(find.text('Reduced motion home 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous property'));
    await tester.pumpAndSettle();
    expect(find.text('Reduced motion home 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous media'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
    const Size(600, 960),
    const Size(800, 1280)
  ]) {
    for (final scale in [1.0, 1.3, 1.6])
      for (final dark in [false, true]) {
        testWidgets(
            'Swipe ${size.width} dark=$dark scale=$scale retains filters and actions',
            (tester) async {
          SharedPreferences.setMockInitialValues(
              {'homes_theme_v1': dark ? 'dark' : 'light'});
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() => {
                tester.view.resetPhysicalSize(),
                tester.view.resetDevicePixelRatio(),
                tester.platformDispatcher.clearTextScaleFactorTestValue()
              });
          final requests = <Uri>[];
          final api = ApiClient(
              baseUrl: 'https://fixture.example.invalid/api/v1',
              client: MockClient((request) async {
                requests.add(request.url);
                final data = List.generate(
                    3,
                    (i) => {
                          ...fixture,
                          '_id': '507f1f77bcf86cd79943901${i + 1}',
                          'title': i == 0
                              ? 'An exceptionally long family home title with plenty of carefully specified details in Ntinda'
                              : 'Short home $i',
                          'price': {
                            'amount': 1500000000000,
                            'currency': 'UGX',
                            'period': 'month'
                          }
                        });
                return http.Response(
                    jsonEncode({
                      'data': data,
                      'pagination': {
                        'page': 1,
                        'limit': 20,
                        'total': 3,
                        'pages': 1
                      }
                    }),
                    200);
              }));
          await tester.pumpWidget(HomesApp(apiClient: api));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discover').last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Rent').first);
          await tester.tap(find.text('Rent').first);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Swipe').first);
          await tester.tap(find.text('Swipe').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Request viewing'), findsOneWidget);
          expect(find.byTooltip('Save property'), findsOneWidget);
          final save = tester.getCenter(find.byTooltip('Save property'));
          await tester.tap(find.byTooltip('Next property'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getCenter(find.byTooltip('Save property')), save);
          await tester.tap(find.text('Grid').first);
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['purpose'], 'rent');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
  }
}

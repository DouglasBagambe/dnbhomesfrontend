import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/core/widgets/brand_loading.dart';
import 'package:homes/core/widgets/states.dart';
import 'package:homes/core/startup/startup_brand_loader.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/features/compare/presentation/compare_screen.dart';
import 'package:homes/features/listings/data/listings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'v2_layout_test.dart' show fixture;

void main() {
  Future<CompareController> mount(WidgetTester tester, List<String> ids,
      Future<http.Response> Function(http.Request) respond) async {
    SharedPreferences.setMockInitialValues({'homes_compare_v1': ids});
    final selection = CompareController();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: selection),
      Provider(
          create: (_) => ListingsRepository(ApiClient(
              baseUrl: 'https://fixture.invalid/api/v1',
              client: MockClient(respond))))
    ], child: const MaterialApp(home: CompareScreen())));
    await tester.pumpAndSettle();
    addTearDown(selection.dispose);
    return selection;
  }

  http.Response property(http.Request r) => http.Response(
      jsonEncode({
        'data': {
          ...fixture,
          '_id': r.url.pathSegments.last,
          'title': 'Home ${r.url.pathSegments.last}',
          'media': <dynamic>[]
        }
      }),
      200);

  testWidgets('empty compare finishes without network requests',
      (tester) async {
    var calls = 0;
    await mount(tester, [], (r) async {
      calls++;
      return property(r);
    });
    expect(find.text('Find your two favourites'), findsOneWidget);
    expect(find.text('Browse homes'), findsOneWidget);
    expect(find.byType(PropertyListSkeleton), findsNothing);
    expect(calls, 0);
  });
  testWidgets('one selection explains how to finish the comparison',
      (tester) async {
    await mount(tester, ['a'], (r) async => property(r));
    expect(find.text('Choose one more home'), findsOneWidget);
    expect(find.textContaining('Home a is ready.'), findsOneWidget);
  });
  testWidgets('two selections render, then clear stays on an empty page',
      (tester) async {
    await mount(tester, ['a', 'b'], (r) async => property(r));
    expect(find.text('Two places. A clearer choice.'), findsOneWidget);
    expect(find.text('Home a'), findsOneWidget);
    expect(find.text('Home b'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Find your two favourites'), findsOneWidget);
  });
  testWidgets(
      'hidden listing is removed and remaining selection remains usable',
      (tester) async {
    final selection = await mount(
        tester,
        ['a', 'b'],
        (r) async => r.url.path.endsWith('/b')
            ? http.Response('{"message":"Not found"}', 404)
            : property(r));
    expect(selection.ids, ['a']);
    expect(find.text('Choose one more home'), findsOneWidget);
    expect(selection.canAdd, isTrue);
  });
  testWidgets('failure resolves to retry and retry loads successfully',
      (tester) async {
    var fail = true;
    await mount(
        tester,
        ['a', 'b'],
        (r) async => fail
            ? http.Response('{"message":"Temporarily unavailable"}', 503)
            : property(r));
    expect(find.byType(AppErrorState), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Two places. A clearer choice.'), findsOneWidget);
  });
  testWidgets('stale requests cannot overwrite cleared comparison',
      (tester) async {
    final response = Completer<http.Response>();
    final selection = await mount(tester, ['a'], (r) => response.future);
    expect(find.byType(PropertyListSkeleton), findsOneWidget);
    await selection.clear();
    await tester.pumpAndSettle();
    response.complete(http.Response(
        jsonEncode({
          'data': {...fixture, '_id': 'a'}
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.text('Find your two favourites'), findsOneWidget);
  });
  testWidgets('symbol loader has no wordmark and respects reduced motion',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(child: BrandLoading()))));
    await tester.pumpAndSettle();
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SignaturePainter>()
        .single;
    expect(painter.markOnly, isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/app.dart';
import 'package:homes/core/state/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/tours/tours_screen.dart';
import 'package:homes/features/tours/tour_video.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'tours_test.dart' show Players, listing, ticks;

class OfflineImages extends BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key,
          Map<String, String>? headers,
          bool withProgress = false}) =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    CachedNetworkImageProvider.defaultCacheManager = OfflineImages();
  });
  for (final dark in [false, true]) {
    for (final size in [const Size(360, 800), const Size(844, 390)]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'Tours gestures, playback and routes at $size scale=$scale dark=$dark',
            (tester) async {
          SharedPreferences.setMockInitialValues(
              {'homes_theme_mode': dark ? 'dark' : 'light'});
          final previous = VideoPlayerPlatform.instance, players = Players();
          VideoPlayerPlatform.instance = players;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          await tester.binding.setSurfaceSize(size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await ticks(tester);
            VideoPlayerPlatform.instance = previous;
            await tester.binding.setSurfaceSize(null);
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            for (final stream in players.streams.values) {
              await stream.close();
            }
          });
          final properties = [listing('a'), listing('b')];
          final api = ApiClient(
              baseUrl: 'https://api.homes.test/api/v1',
              client: MockClient((request) async {
                final id = request.url.pathSegments.last;
                if (id == 'a' || id == 'b')
                  return http.Response(
                      jsonEncode({
                        'data': properties.firstWhere((p) => p['_id'] == id)
                      }),
                      200);
                return http.Response(
                    jsonEncode({
                      'data': properties,
                      'pagination': {
                        'page': 1,
                        'pages': 1,
                        'total': 2,
                        'limit': 50
                      }
                    }),
                    200);
              }));
          await tester.pumpWidget(HomesApp(apiClient: api));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Open Reels'));
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(find.byType(ToursScreen), findsOneWidget);
          expect(players.active.length, 1);
          expect(tester.takeException(), isNull);
          final firstUrl = tester
              .widgetList<TourVideo>(find.byType(TourVideo))
              .firstWhere((v) => v.active)
              .url;
          final horizontal = find
              .descendant(
                  of: find.byType(ToursScreen),
                  matching: find.byWidgetPredicate((w) =>
                      w is PageView && w.scrollDirection == Axis.horizontal))
              .first;
          await tester.drag(horizontal, Offset(-size.width * .85, 0));
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active.length, 1);
          expect(
              tester
                  .widgetList<TourVideo>(find.byType(TourVideo))
                  .firstWhere((v) => v.active)
                  .url,
              isNot(firstUrl));
          await tester.drag(horizontal, Offset(-size.width * .85, 0));
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active, isEmpty,
              reason: 'Photos must stop video playback');
          final vertical = find.descendant(
              of: find.byType(ToursScreen),
              matching: find.byWidgetPredicate(
                  (w) => w is PageView && w.scrollDirection == Axis.vertical));
          await tester.drag(vertical, Offset(0, -size.height * .85));
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active.length, 1);
          await tester.tap(find.text('All locations'));
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active, isEmpty,
              reason: 'Location sheet pauses playback');
          final picker = find.byType(TextField).hitTestable().last;
          expect(Theme.of(tester.element(picker)).brightness,
              dark ? Brightness.dark : Brightness.light);
          final theme =
              tester.element(find.byType(ToursScreen)).read<ThemeController>();
          await theme.setMode(dark ? ThemeMode.light : ThemeMode.dark);
          await tester.pump(const Duration(milliseconds: 300));
          await ticks(tester);
          final heading = tester.renderObject<RenderParagraph>(
              find.text('Where would you like to explore?'));
          expect(heading.text.style?.color,
              Theme.of(tester.element(picker)).textTheme.bodyMedium?.color,
              reason:
                  'The heading must inherit the sheet theme, not Tours media chrome');
          await theme.setMode(dark ? ThemeMode.dark : ThemeMode.light);
          await tester.pump(const Duration(milliseconds: 300));
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pump();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pump();
          await tester.tap(find.byTooltip('Close location picker'));
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active.length, 1);
          // The metadata scrolls at large text / short heights; all actions remain reachable.
          final view = find.text('View property').hitTestable();
          if (view.evaluate().isEmpty) {
            await tester.drag(
                find.byType(SingleChildScrollView).last, const Offset(0, -300));
            await tester.pump();
          }
          await tester.tap(find.text('View property').hitTestable().last);
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active, isEmpty,
              reason: 'Covered Tours route must stop audio');
          await tester.pageBack();
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(players.active.length, 1);
          expect(players.maximumActive, 1);
          // Closing immersive Tours must restore root status/navigation contrast.
          await tester.tap(find.byTooltip('Close Reels'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await ticks(tester);
          expect(find.byType(ToursScreen), findsNothing);
          final systemBars =
              tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                  find.byKey(const ValueKey('app-system-bars')));
          expect(systemBars.value.statusBarIconBrightness,
              dark ? Brightness.light : Brightness.dark);
          expect(systemBars.value.systemNavigationBarIconBrightness,
              dark ? Brightness.light : Brightness.dark);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await ticks(tester);
          expect(players.active, isEmpty);
        });
      }
    }
  }
}

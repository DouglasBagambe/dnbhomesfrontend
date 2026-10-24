import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/features/listings/data/listings_repository.dart';
import 'package:homes/features/listings/domain/property.dart';
import 'package:homes/features/tours/tours_feed.dart';
import 'package:homes/features/tours/tour_video.dart';
import 'package:homes/features/tours/tour_backdrop.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

Map<String, dynamic> listing(String id, {List<Map<String, String>>? media}) => {
      '_id': id,
      'title': 'Home $id',
      'status': 'published',
      'location': {'area': 'Ntinda', 'district': 'Kampala'},
      'media': media ??
          [
            {'type': 'image', 'url': 'https://media.homes.test/photo.jpg'},
            {'type': 'video', 'url': 'https://media.homes.test/$id.mp4'},
            {'type': 'video', 'url': 'https://media.homes.test/$id-second.mp4'}
          ],
    };
http.Response result(List<Map<String, dynamic>> data, int page, int pages) =>
    http.Response(
        jsonEncode({
          'data': data,
          'pagination': {
            'page': page,
            'pages': pages,
            'total': 100,
            'limit': 50
          }
        }),
        200);
ToursFeed source(
        Future<http.Response> Function(http.Request) handler) =>
    ToursFeed(
        ListingsRepository(ApiClient(
            baseUrl: 'https://api.homes.test/api/v1',
            client: MockClient(handler))),
        random: Random(7));

class Players extends VideoPlayerPlatform {
  int next = 0, maximumActive = 0;
  final streams = <int, StreamController<VideoEvent>>{};
  final active = <int>{};
  final disposed = <int>[];
  final volumes = <int, double>{};
  bool holdInitialization = false;
  void initialized(int id) {
    if (!streams[id]!.isClosed)
      streams[id]!.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 15),
          size: const Size(720, 1280)));
  }

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    final id = ++next;
    streams[id] = StreamController.broadcast();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) {
    if (!holdInitialization) Future.microtask(() => initialized(id));
    return streams[id]!.stream;
  }

  @override
  Future<void> play(int id) async {
    active.add(id);
    maximumActive = max(maximumActive, active.length);
  }

  @override
  Future<void> pause(int id) async {
    active.remove(id);
  }

  @override
  Future<void> dispose(int id) async {
    active.remove(id);
    disposed.add(id);
  }

  @override
  Future<void> setVolume(int id, double value) async {
    volumes[id] = value;
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> seekTo(int id, Duration value) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildView(int id) =>
      ColoredBox(key: ValueKey('video-$id'), color: Colors.green);
}

Future<void> ticks(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  test(
      'Tours groups properties, prioritizes videos and never invents a video from photos',
      () {
    final clips = ToursFeed.videos([
      Property.fromJson(listing('a')),
      Property.fromJson(listing('b', media: [
        {'type': 'image', 'url': 'https://media.homes.test/b.jpg'}
      ])),
      Property.fromJson({...listing('c'), 'status': 'archived'}),
      Property.fromJson(listing('d', media: [
        {'type': 'video', 'url': 'javascript:alert(1)'}
      ])),
    ]);
    expect(clips.length, 1);
    expect(clips.single.media.map((m) => m.type), ['video', 'video', 'image']);
    expect(clips.single.property.id, 'a');
  });
  test(
      'Sparse catalogue scans past photo-only pages and duplicate IDs stay out',
      () async {
    final feed = source((r) async {
      final page = int.parse(r.url.queryParameters['page']!);
      return result(
          page == 1
              ? [listing('photos', media: [])]
              : [listing('video'), listing('video')],
          page,
          2);
    });
    await feed.more();
    expect(feed.page, 2);
    expect(feed.clips.length, 1);
    expect(feed.hasMore, false);
    feed.dispose();
  });
  test('Location changes reject stale results and send both area and district',
      () async {
    final stale = Completer<http.Response>();
    final requests = <Uri>[];
    final feed = source((r) async {
      requests.add(r.url);
      return r.url.queryParameters['area'] == 'Ntinda'
          ? await stale.future
          : result([listing('current')], 1, 1);
    });
    final old = feed.select(const TourLocation('Ntinda', 'Kampala'));
    await Future<void>.delayed(Duration.zero);
    await feed.select(const TourLocation('Kira', 'Wakiso'));
    stale.complete(result([listing('stale')], 1, 1));
    await old;
    expect(feed.clips.single.id, 'current');
    expect(requests.last.queryParameters['district'], 'Wakiso');
    feed.dispose();
  });
  test(
      'A failed later page retains earlier tours and retry stays on the failed page',
      () async {
    var fail = true;
    final requested = <String?>[];
    final feed = source((r) async {
      final p = r.url.queryParameters['page'];
      requested.add(p);
      if (p == '2' && fail) throw Exception('offline');
      return result([listing(p!)], int.parse(p), 2);
    });
    await feed.more();
    await feed.more();
    expect(feed.clips.length, 1);
    expect(feed.error, isNotNull);
    fail = false;
    await feed.more();
    expect(requested, ['1', '2', '2']);
    expect(feed.clips.length, 2);
    feed.dispose();
  });
  test(
      'Availability is backward-compatible, explicit nonavailable statuses close viewings',
      () {
    expect(Property.fromJson(listing('a')).canRequestViewing, true);
    for (final status in [
      'reserved',
      'rented',
      'sold',
      'unavailable',
      'future_status'
    ]) {
      final p =
          Property.fromJson({...listing('a'), 'availabilityStatus': status});
      expect(p.canRequestViewing, false);
      expect(p.availabilityLabel, isNotNull);
    }
    expect(
        Property.fromJson({...listing('a'), 'availabilityStatus': 'available'})
            .availabilityLabel,
        'Available');
  });
  late VideoPlayerPlatform previous;
  late Players players;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    players = Players();
    VideoPlayerPlatform.instance = players;
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = previous;
    for (final s in players.streams.values) {
      await s.close();
    }
  });
  Widget video(
          {bool active = true,
          bool muted = true,
          String url = 'https://media.homes.test/a.mp4'}) =>
      MaterialApp(
          home: Scaffold(
              body: TourVideo(
                  key: const ValueKey('tour'),
                  url: url,
                  active: active,
                  muted: muted)));
  testWidgets(
      'Only the active video plays, muted by default, pauses offscreen and resumes on return',
      (tester) async {
    VideoPlayerPlatform.instance = players;
    await tester.pumpWidget(video());
    await ticks(tester);
    expect(players.active.length, 1);
    expect(find.byType(TourBackdrop), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget,
        reason:
            'The ambient backdrop must not add another video texture or decoder');
    expect(players.next, 1);
    expect(players.volumes.values.every((v) => v == 0), true);
    await tester.pumpWidget(video(active: false));
    await ticks(tester);
    expect(players.active, isEmpty);
    expect(players.disposed.length, 1);
    await tester.pumpWidget(video(muted: false));
    await ticks(tester);
    expect(players.active.length, 1);
    expect(players.volumes.values.last, 1);
    expect(players.maximumActive, 1);
    await tester.pumpWidget(const SizedBox());
    await ticks(tester);
    expect(players.active, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Backgrounding releases playback; a manual pause survives resume',
      (tester) async {
    VideoPlayerPlatform.instance = players;
    await tester.pumpWidget(video());
    await ticks(tester);
    await tester.tap(find.byTooltip('Pause video'));
    await ticks(tester);
    expect(players.active, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await ticks(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await ticks(tester);
    expect(players.active, isEmpty);
    await tester.tap(find.byTooltip('Play video'));
    await ticks(tester);
    expect(players.active.length, 1);
    await tester.pumpWidget(const SizedBox());
    await ticks(tester);
  });
  testWidgets(
      'Late initialization after fast swiping cannot start an invisible video',
      (tester) async {
    players.holdInitialization = true;
    VideoPlayerPlatform.instance = players;
    await tester.pumpWidget(video());
    await ticks(tester);
    await tester.pumpWidget(video(active: false));
    await tester.pump();
    players.initialized(1);
    await ticks(tester);
    expect(players.active, isEmpty);
    expect(players.disposed, contains(1));
    await tester.pumpWidget(const SizedBox());
    await ticks(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Video decoding errors offer retry without losing navigation',
      (tester) async {
    VideoPlayerPlatform.instance = players;
    await tester.pumpWidget(video());
    await ticks(tester);
    players.streams[1]!.addError(
        PlatformException(code: 'VideoError', message: 'unsupported codec'));
    await ticks(tester);
    expect(find.text('This video couldn’t play.'), findsOneWidget);
    await tester.tap(find.text('Retry video'));
    await ticks(tester);
    expect(players.next, 2);
    expect(players.active.length, 1);
    await tester.pumpWidget(const SizedBox());
    await ticks(tester);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/features/listings/domain/property.dart';
import 'package:homes/features/listings/presentation/media_gallery.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class VideoFixture extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  int plays = 0, pauses = 0, disposed = 0;
  double volume = 1;
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    Future.microtask(() => events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(640, 360))));
    return events.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
  }

  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
  }

  @override
  Future<void> setVolume(int playerId, double value) async {
    volume = value;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) =>
      const ColoredBox(key: ValueKey('decoded-video'), color: Colors.blue);
}

void main() {
  testWidgets(
      'short immersive stage keeps a visible video frame and pauses without resuming',
      (tester) async {
    final previous = VideoPlayerPlatform.instance, fixture = VideoFixture();
    VideoPlayerPlatform.instance = fixture;
    addTearDown(() async {
      VideoPlayerPlatform.instance = previous;
      await fixture.events.close();
    });
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 360,
                height: 160,
                child: MediaGallery(
                    title: 'Video QA',
                    fullscreen: true,
                    immersive: true,
                    media: [
                      PropertyMedia(
                          type: 'video',
                          url: 'https://qa.example.invalid/video.mp4')
                    ])))));
    expect(fixture.plays, 0);
    await tester.tap(find.byTooltip('Play video'));
    await tester.pump();
    for (var i = 0; i < 10 && fixture.plays == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(fixture.plays, 1);
    expect(fixture.volume, 0);
    final frame = tester.getSize(find.byKey(const ValueKey('decoded-video')));
    expect(frame.height, greaterThan(100));
    expect(frame.width, greaterThan(200));
    final pauses = fixture.pauses;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(fixture.pauses, greaterThan(pauses));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fixture.plays, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    for (var i = 0; i < 10 && fixture.disposed == 0; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    expect(fixture.disposed, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:homes/core/navigation_observer.dart';
import 'package:homes/features/listings/domain/property.dart';
import 'package:homes/features/listings/presentation/media_gallery.dart';

void main() {
  testWidgets(
      '25-item gallery counts videos, creates no player before play and fullscreen back is safe',
      (tester) async {
    final media = List.generate(
        25,
        (i) => PropertyMedia(
            url: 'https://example.test/media/$i',
            type: i < 20 ? 'image' : 'video',
            alt: 'QA media ${i + 1}'));
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [homesRouteObserver],
        home: Scaffold(
            body: SizedBox(
                height: 350,
                child: MediaGallery(
                    media: media, title: 'QA', initialIndex: 20)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('21 / 25'), findsOneWidget);
    expect(find.textContaining('20 images · 5 videos'), findsOneWidget);
    expect(find.byTooltip('Play video'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
    await tester.tap(find.byTooltip('Open full gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Property media'), findsOneWidget);
    await tester.tap(find.byTooltip('Next media'));
    await tester.pumpAndSettle();
    expect(find.textContaining('22 / 25'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('21 / 25'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

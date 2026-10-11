import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/startup/startup_brand_loader.dart';
import 'package:homes/core/startup/signature_paths.dart';

void main() {
  Widget app(Future<void> ready, {bool reduced = false, bool dark = false}) =>
      MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StartupBrandGate(
                  ready: ready, child: const Text('Homes content'))));

  testWidgets(
      'one opening holds final state for bootstrap, fades and never replays',
      (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(app(ready.future));
    await tester.pump(const Duration(milliseconds: 4080));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
        tester
            .widget<IgnorePointer>(
                find.byKey(const ValueKey('startup-content')))
            .ignoring,
        isTrue);
    ready.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Entering Homes'), findsNothing);
    await tester.pumpWidget(app(ready.future));
    expect(find.bySemanticsLabel('Entering Homes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reduced motion completes vectors immediately and uses a short fade',
      (tester) async {
    await tester.pumpWidget(app(Future.value(), reduced: true, dark: true));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<SignaturePainter>()
        .single;
    expect(painter.reduced, isTrue);
    expect(painter.dark, isTrue);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Entering Homes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during startup stops the controller cleanly',
      (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(app(ready.future));
    await tester.pumpWidget(const SizedBox());
    ready.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('approved geometry and exact bounded sequence', () {
    expect(signaturePaths.length, 13);
    expect(signaturePaths[5], 'M0,0 L0,100');
    expect(signatureWordDelays.last + signatureWordDurations.last, 3635);
    expect(signaturePaths[8], 'M138,0 A44,50 0 1 0 138,100 A44,50 0 1 0 138,0');
  });
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'approved composition ${size.width} dark=$dark fits and renders',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            home: RepaintBoundary(
                key: key,
                child: StartupBrandGate(
                    ready: Completer<void>().future, child: const SizedBox())),
            theme: dark ? ThemeData.dark() : ThemeData.light()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4080));
        expect(tester.takeException(), isNull);
        final output = Platform.environment['HOMES_LOADER_CAPTURE_DIR'];
        if (output != null) {
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$output/flutter-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/state/theme_controller.dart';
import 'package:homes/core/theme/app_theme.dart';
import 'package:homes/core/widgets/brand_loading.dart';
import 'package:homes/core/widgets/states.dart';
import 'package:homes/features/settings/presentation/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final dark in [false, true]) {
    for (final size in [const Size(360, 800), const Size(844, 390)]) {
      testWidgets('loading layouts fit $size dark=$dark at large text',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final content in [
          const PropertyListSkeleton(columns: 2),
          const PropertyDetailSkeleton()
        ]) {
          await tester.pumpWidget(MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: MediaQuery(
                  data: MediaQueryData(
                      size: size, textScaler: const TextScaler.linear(1.6)),
                  child: Scaffold(body: content))));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        }
      });
    }
  }
  testWidgets('pull to refresh uses the symbol and completes cleanly',
      (tester) async {
    final done = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BrandRefreshIndicator(
                onRefresh: () => done.future,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 900, child: Text('Homes'))
                    ])))));
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(BrandLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BrandLoading), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings has preferences without another account link',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeController();
    await theme.ready;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: theme, child: const MaterialApp(home: SettingsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Your Homes account'), findsNothing);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    theme.dispose();
  });
  testWidgets('capture symbol and skeleton for visual review', (tester) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
            key: key,
            child: const Scaffold(
                body: SafeArea(
                    child: Column(children: [
              SizedBox(
                  height: 100, child: Center(child: BrandLoading(size: 64))),
              Expanded(child: PropertyListSkeleton(columns: 2))
            ]))))));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(tester.takeException(), isNull);
    if (Platform.environment['HOMES_CAPTURE_LOADING'] != null) {
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${Platform.environment['HOMES_CAPTURE_LOADING']}/loading-light.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}

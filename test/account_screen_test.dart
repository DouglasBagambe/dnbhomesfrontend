import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:homes/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homes/core/network/api_client.dart';
import 'package:homes/core/config/app_config.dart';
import 'package:homes/features/accounts/account_screen.dart';
import 'package:homes/features/accounts/consumer_controller.dart';
import 'package:homes/features/bookings/bookings_controller.dart';
import 'package:homes/features/compare/compare_controller.dart';
import 'package:homes/features/favorites/favorites_controller.dart';

class _Session implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

Future<ConsumerController> account({bool providers = false}) async {
  SharedPreferences.setMockInitialValues({});
  final api = ApiClient(
      baseUrl: 'https://qa.example.invalid/api/v1',
      client: MockClient((request) async => http.Response(
          jsonEncode({
            'data': {
              'accounts': true,
              'providers': {'google': providers, 'apple': providers}
            }
          }),
          200)));
  final value = ConsumerController(
      api, FavoritesController(), CompareController(), BookingsController(),
      sessionStore: _Session());
  await value.ready;
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final directory = Platform.environment['HOMES_QA_FONT_DIR'];
    if (directory != null) {
      final loader = FontLoader('Roboto');
      for (final name in ['Regular', 'Medium', 'Bold']) {
        loader.addFont(File('$directory/Roboto-$name.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      }
      await loader.load();
      final fallback = FontLoader('Ahem');
      fallback.addFont(File('$directory/Roboto-Regular.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
      await fallback.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(File('$directory/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
      await icons.load();
    }
  });
  test(
      'provider placeholders stay isolated from production and real client IDs',
      () {
    expect(
        AppConfig.isPreviewProvider(
            '123456789012-previewhomes.apps.googleusercontent.com',
            environmentName: 'staging'),
        isTrue);
    expect(
        AppConfig.isPreviewProvider('com.nilebitlabs.dnbhomes.preview.web',
            environmentName: 'staging'),
        isTrue);
    expect(
        AppConfig.isPreviewProvider('123-real.apps.googleusercontent.com',
            environmentName: 'staging'),
        isFalse);
    expect(
        AppConfig.isPreviewProvider('com.nilebitlabs.dnbhomes.preview.web',
            environmentName: 'production'),
        isFalse);
  });
  if (AppConfig.isPreviewProvider(AppConfig.googleWebClientId)) {
    testWidgets(
        'preview providers remain visible and do not invoke native OAuth',
        (tester) async {
      final value = await account(providers: true);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: value,
          child:
              MaterialApp(theme: AppTheme.light, home: const AccountScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('continue-google')));
      await tester.pumpAndSettle();
      expect(find.text('Google sign-in will be available at launch.'),
          findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('continue-apple')));
      await tester.tap(find.byKey(const ValueKey('continue-apple')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Apple sign-in will be available at launch.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      value.dispose();
    });
  }
  for (final width in [390.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'account entry $width dark=$dark: compact, email first, providers gated',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final value = await account();
        final key = GlobalKey();
        await tester.pumpWidget(ChangeNotifierProvider.value(
            value: value,
            child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                home:
                    RepaintBoundary(key: key, child: const AccountScreen()))));
        await tester.pumpAndSettle();
        expect(find.text("Let's find you a home."), findsOneWidget);
        expect(find.byKey(const ValueKey('continue-google')), findsNothing);
        expect(find.byKey(const ValueKey('continue-apple')), findsNothing);
        expect(find.text('Continue as guest'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['HOMES_ACCOUNT_CAPTURE_DIR'];
        if (output != null)
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$output/flutter-${width.toInt()}-${dark ? 'dark' : 'light'}.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextFormField, 'Phone (optional)'),
            findsNothing);
        expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        value.dispose();
      });
    }
  }
}

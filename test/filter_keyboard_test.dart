import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/theme/app_theme.dart';
import 'package:homes/features/discover/presentation/filter_sheet.dart';
import 'package:homes/features/listings/data/listings_repository.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('filter Apply stays above keyboard at $size scale=$scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        onPressed: () =>
                            FilterSheet.show(context, const ListingQuery()),
                        child: const Text('Open'),
                      ))),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final keyboardHeight = size.height < 500 ? 180.0 : 300.0;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.text('Apply filters')).bottom,
            lessThanOrEqualTo(size.height - keyboardHeight));
        await tester.tap(find.text('Apply filters'));
        await tester.pumpAndSettle();
        expect(find.byType(FilterSheet), findsNothing);
      });
    }
  }
}

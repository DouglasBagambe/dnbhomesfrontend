import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/widgets/states.dart';

void main() {
  for (final error in [false, true]) {
    testWidgets(
        '${error ? 'error' : 'empty'} state action remains usable in a short viewport',
        (tester) async {
      var calls = 0;
      final label = error ? 'Try again' : 'Clear filters';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 120,
              child: error
                  ? AppErrorState(
                      message: 'Connection unavailable', onRetry: () => calls++)
                  : AppEmptyState(
                      icon: Icons.home_outlined,
                      title: 'No properties found',
                      message: 'Clear a filter or try a nearby location.',
                      action: TextButton(
                          onPressed: () => calls++, child: Text(label)),
                    ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      expect(calls, 1);
    });
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/telemetry/telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Telemetry.initialize();
  runZonedGuarded(() => runApp(const HomesApp()), (error, stack) {
    /* Sentry capture is enabled here when configured. */
  });
}

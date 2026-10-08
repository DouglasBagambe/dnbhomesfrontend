import 'package:flutter/material.dart';
import 'app.dart';
import 'core/telemetry/telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Telemetry.initialize();
  runApp(const HomesApp());
}

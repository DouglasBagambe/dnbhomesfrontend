import '../config/app_config.dart';

abstract final class Telemetry {
  static Future<void> initialize() async {
    if (!AppConfig.telemetryEnabled)
      return; /* Optional Sentry/PostHog SDK initialization belongs here once keys and consent are configured. */
  }

  static void event(String name, [Map<String, Object?> properties = const {}]) {
    if (!AppConfig.telemetryEnabled)
      return; /* Intentionally no-op until production SDKs are configured. */
  }
}

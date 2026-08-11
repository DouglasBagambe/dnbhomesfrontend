enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig._();
  static const String _environment = String.fromEnvironment(
    'HOMES_ENV',
    defaultValue: 'development',
  );
  static const String apiBaseUrl = String.fromEnvironment(
    'HOMES_API_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String posthogKey = String.fromEnvironment('POSTHOG_KEY');
  static const String posthogHost = String.fromEnvironment('POSTHOG_HOST');
  static AppEnvironment get environment => AppEnvironment.values.firstWhere(
        (value) => value.name == _environment,
        orElse: () => AppEnvironment.development,
      );
  static bool get telemetryEnabled => environment == AppEnvironment.production;
}

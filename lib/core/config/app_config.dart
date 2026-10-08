import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
      );
  static void validate() => validateValues(
        environmentName: _environment,
        apiUrl: apiBaseUrl,
        release: kReleaseMode,
        flavor: appFlavor,
        buildValidation: const bool.fromEnvironment('HOMES_BUILD_VALIDATION'),
      );
  static void validateValues({
    required String environmentName,
    required String apiUrl,
    required bool release,
    String? flavor,
    bool buildValidation = false,
  }) {
    if (!AppEnvironment.values.any((value) => value.name == environmentName)) {
      throw StateError('Unknown HOMES_ENV');
    }
    if (buildValidation) {
      throw StateError('Unsigned build validation artifacts cannot run');
    }
    if ((release || flavor == 'production') &&
        (environmentName != flavor || flavor == null)) {
      throw StateError('Release environment must match the explicit flavor');
    }
    final uri = Uri.tryParse(apiUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/api/v1') {
      throw StateError('HOMES_API_URL must be an API root ending /api/v1');
    }
    if (environmentName != 'development') {
      final host = uri.host.toLowerCase();
      final reserved = !host.contains('.') ||
          RegExp(r'^[0-9.]+$').hasMatch(host) ||
          host.contains(':') ||
          RegExp(r'\.(invalid|test|local|localhost|example)$').hasMatch(host) ||
          RegExp(r'(^|\.)example\.(com|net|org)$').hasMatch(host);
      if (uri.scheme != 'https' || reserved) {
        throw StateError('Staging/production require a public HTTPS API URL');
      }
    } else if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw StateError('Invalid development API scheme');
    }
  }

  static bool get telemetryEnabled => environment == AppEnvironment.production;
}

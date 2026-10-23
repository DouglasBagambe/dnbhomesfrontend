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
    defaultValue: 'https://homes-api.nilebitlabs.com/api/v1',
  );
  static const String websiteUrl = String.fromEnvironment(
    'HOMES_WEBSITE_URL',
    defaultValue: 'https://dnbhomeswebsite-psi.vercel.app',
  );
  static const String googleWebClientId =
      String.fromEnvironment('HOMES_GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId =
      String.fromEnvironment('HOMES_GOOGLE_IOS_CLIENT_ID');
  static const String appleServiceId =
      String.fromEnvironment('HOMES_APPLE_SERVICE_ID');
  static const String appleRedirectUri =
      String.fromEnvironment('HOMES_APPLE_REDIRECT_URI');
  static bool isPreviewProvider(String clientId, {String? environmentName}) =>
      (environmentName ?? _environment) != 'production' &&
      const [
        '123456789012-previewhomes.apps.googleusercontent.com',
        'com.nilebitlabs.dnbhomes.preview.web'
      ].contains(clientId);
  static String propertyUrl(String slug, String id) =>
      Uri.parse(websiteUrl).resolve('/properties/$slug-$id').toString();
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
        flavor: appFlavor ??
            (defaultTargetPlatform == TargetPlatform.iOS ? _environment : null),
        buildValidation: const bool.fromEnvironment('HOMES_BUILD_VALIDATION'),
        googleWebClientId: googleWebClientId,
        googleIosClientId: googleIosClientId,
        appleServiceId: appleServiceId,
        appleRedirectUri: appleRedirectUri,
      );
  static void validateValues({
    required String environmentName,
    required String apiUrl,
    required bool release,
    String? flavor,
    bool buildValidation = false,
    String googleWebClientId = '',
    String googleIosClientId = '',
    String appleServiceId = '',
    String appleRedirectUri = '',
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
    // Android obtains public provider IDs from the authenticated API origin's
    // capabilities endpoint. iOS still needs native URL-scheme configuration.
    if (environmentName == 'production' &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      if (googleWebClientId.isEmpty) {
        throw StateError('Production requires HOMES_GOOGLE_WEB_CLIENT_ID');
      }
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          googleIosClientId.isEmpty) {
        throw StateError('Production iOS requires HOMES_GOOGLE_IOS_CLIENT_ID');
      }
      if (appleServiceId.isEmpty || appleRedirectUri.isEmpty) {
        throw StateError(
            'Production requires HOMES_APPLE_SERVICE_ID and HOMES_APPLE_REDIRECT_URI');
      }
      final appleUri = Uri.tryParse(appleRedirectUri);
      if (appleUri == null ||
          appleUri.scheme != 'https' ||
          appleUri.host != uri.host ||
          !appleUri.path.startsWith('/api/v1/consumer/apple/callback/')) {
        throw StateError(
            'HOMES_APPLE_REDIRECT_URI must use the production API Apple callback');
      }
    }
  }

  static bool get telemetryEnabled => environment == AppEnvironment.production;
}

import 'app_config.dart';

/// Only public settings are accepted here. Provider secrets stay on the server.
class RuntimeConfig {
  const RuntimeConfig(
      {this.googleWebClientId = '',
      this.appleServiceId = '',
      this.supportEmail = '',
      this.supportPhone = '',
      this.supportWhatsapp = ''});
  final String googleWebClientId, appleServiceId;
  final String supportEmail, supportPhone, supportWhatsapp;
  factory RuntimeConfig.fromJson(Map<dynamic, dynamic> json) {
    String text(String key) =>
        json[key] is String ? (json[key] as String).trim() : '';
    final google = text('googleWebClientId');
    final apple = text('appleServiceId');
    final email = text('supportEmail');
    String phone(String key) {
      final value = text(key);
      return RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(value) ? value : '';
    }

    return RuntimeConfig(
        googleWebClientId:
            RegExp(r'^[a-zA-Z0-9-]+\.apps\.googleusercontent\.com$')
                        .hasMatch(google) &&
                    !google.contains('previewhomes')
                ? google
                : '',
        appleServiceId:
            RegExp(r'^[a-zA-Z0-9]+(?:[.-][a-zA-Z0-9]+)+$').hasMatch(apple) &&
                    !apple.contains('.preview.')
                ? apple
                : '',
        supportEmail:
            RegExp(r'^[^\s@?&#]+@[^\s@?&#]+\.[^\s@?&#]+$').hasMatch(email)
                ? email
                : '',
        supportPhone: phone('supportPhone'),
        supportWhatsapp: phone('supportWhatsapp'));
  }
  String get appleRedirectUri =>
      '${AppConfig.apiBaseUrl}/consumer/apple/callback/${AppConfig.environment == AppEnvironment.production ? 'production' : 'staging'}';
}

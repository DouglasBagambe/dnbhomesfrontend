import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/config/app_config.dart';
import 'package:homes/core/config/runtime_config.dart';

void main() {
  test('public runtime config accepts provider IDs and international contacts',
      () {
    final config = RuntimeConfig.fromJson({
      'googleWebClientId': '123456789-real.apps.googleusercontent.com',
      'appleServiceId': 'com.homes.signin',
      'supportEmail': 'help@homes.co.ug',
      'supportPhone': '+256700123456',
      'supportWhatsapp': '+256700123456',
      'secret': 'NEVER-USED'
    });
    expect(
        config.googleWebClientId, '123456789-real.apps.googleusercontent.com');
    expect(config.appleServiceId, 'com.homes.signin');
    expect(config.supportEmail, 'help@homes.co.ug');
    expect(config.supportPhone, '+256700123456');
    expect(config.appleRedirectUri,
        startsWith('${AppConfig.apiBaseUrl}/consumer/apple/callback/'));
  });
  test('runtime config rejects preview identities and contact/link injection',
      () {
    final config = RuntimeConfig.fromJson({
      'googleWebClientId': '123-previewhomes.apps.googleusercontent.com',
      'appleServiceId': 'com.homes.preview.web',
      'supportEmail': 'help@homes.co.ug?body=bad',
      'supportPhone': 'tel:bad',
      'supportWhatsapp': '+256700123456?text=bad'
    });
    expect(config.googleWebClientId, '');
    expect(config.appleServiceId, '');
    expect(config.supportEmail, '');
    expect(config.supportPhone, '');
    expect(config.supportWhatsapp, '');
  });
  test(
      'missing runtime settings preserve guest browsing without fake credentials',
      () {
    final config = RuntimeConfig.fromJson({});
    expect(config.googleWebClientId, '');
    expect(config.supportEmail, '');
    AppConfig.validateValues(
        environmentName: 'production',
        flavor: 'production',
        apiUrl: 'https://homes-api.nilebitlabs.com/api/v1',
        release: true);
  });
}

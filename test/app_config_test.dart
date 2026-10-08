import 'package:flutter_test/flutter_test.dart';
import 'package:homes/core/config/app_config.dart';

void main() {
  test('production rejects omitted, placeholder and local API configuration',
      () {
    for (final url in [
      '',
      'https://api.example.invalid/api/v1',
      'https://api.example.com/api/v1',
      'http://10.0.2.2:3000/api/v1'
    ]) {
      expect(
          () => AppConfig.validateValues(
              environmentName: 'production',
              apiUrl: url,
              release: true,
              flavor: 'production'),
          throwsStateError);
    }
    expect(
        () => AppConfig.validateValues(
            environmentName: 'development',
            apiUrl: 'http://10.0.2.2:3000/api/v1',
            release: true,
            flavor: 'production'),
        throwsStateError);
  });
  test('explicit production endpoint and convenient dev endpoint are accepted',
      () {
    AppConfig.validateValues(
        environmentName: 'production',
        apiUrl: 'https://api.homes-fixture.co.ug/api/v1',
        release: true,
        flavor: 'production');
    AppConfig.validateValues(
        environmentName: 'development',
        apiUrl: 'http://10.0.2.2:3000/api/v1',
        release: false,
        flavor: 'development');
  });
  test('unknown environments and validation artifacts cannot run', () {
    expect(
        () => AppConfig.validateValues(
            environmentName: 'prodution',
            apiUrl: 'https://api.homes-fixture.co.ug/api/v1',
            release: true,
            flavor: 'production'),
        throwsStateError);
    expect(
        () => AppConfig.validateValues(
            environmentName: 'production',
            apiUrl: 'http://127.0.0.1:3000/api/v1',
            release: true,
            flavor: 'production',
            buildValidation: true),
        throwsStateError);
  });
}

# Homes

Flutter consumer property application operated by dnb Homes.

## Environments

```bash
flutter run --flavor development --dart-define=HOMES_ENV=development --dart-define=HOMES_API_URL=http://10.0.2.2:3000/api/v1
flutter build appbundle --release --flavor production --dart-define=HOMES_ENV=production --dart-define=HOMES_API_URL=https://api.example.com/api/v1
```

Production API URLs, Sentry DSNs, and PostHog keys must be supplied using `--dart-define`; none are committed.

## Android signing

Create an upload keystore outside the repository. Copy `android/key.properties.example` to `android/key.properties`, use an absolute keystore path, and never commit either file or credentials. Without `key.properties`, Gradle can create an unsigned release bundle for CI validation but it cannot be uploaded to Play.

Android App Links are prepared for `https://dnbhomes.com/properties/*`. The website must publish `/.well-known/assetlinks.json` containing `com.nilebitlabs.dnbhomes` and the final Play signing certificate fingerprint before verified links work.

## Telemetry

Optional Sentry/PostHog configuration boundaries exist in `lib/core/telemetry`. Add the SDK packages and consent controls when production keys and privacy approval are available.

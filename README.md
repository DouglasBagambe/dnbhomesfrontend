# Homes

Flutter consumer property application operated by dnb Homes.

The app uses the official supplied black/white mark for launcher, adaptive icon, splash, and the theme-aware Home header. The retired gradient W/roof assets have been removed.

## Local toolchain

Use Flutter 3.38.1 (Dart 3.10.0) and JDK 17, matching CI and the committed lockfile. Android builds compile and target API 36 (Android 16), meeting the [current Play target API requirement](https://developer.android.com/google/play/requirements/target-sdk). The toolchain requires SDK 36, NDK 27.0.12077973, AGP 8.12.1, Gradle 8.13 and Kotlin 2.2.0; the locked `share_plus 13.2.0` requires this build-tool baseline. Install dependencies with `flutter pub get --enforce-lockfile`. Gradle defaults to two workers with a 3 GB heap so it can run alongside the local stack; override those locally only when the machine has enough memory.

## Environments

```bash
flutter run --flavor development --dart-define=HOMES_ENV=development --dart-define=HOMES_API_URL=http://10.0.2.2:3000/api/v1
flutter build appbundle --release --flavor production --dart-define=HOMES_ENV=production --dart-define=HOMES_API_URL=https://api.example.com/api/v1
```

For an Android emulator, use the development URL above. Forward the API port with `adb reverse tcp:3000 tcp:3000` so local demo media URLs (`localhost:3000`) also resolve on the device. For a USB device, use the same forwarding command and `HOMES_API_URL=http://127.0.0.1:3000/api/v1`.

Production API URLs, Sentry DSNs, and PostHog keys must be supplied using `--dart-define`; none are committed.

Validate with `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, a development `flutter build apk`, and the production `flutter build appbundle` command. A production bundle without a real upload keystore is only a build-validation artifact. Android pins DataStore 1.2.1 because the preferences dependency graph previously bundled a native counter with misaligned 16 KB RELRO segments. Check 64-bit native LOAD/RELRO alignment and APK ZIP alignment before release.

## Android signing

Create an upload keystore outside the repository. Copy `android/key.properties.example` to `android/key.properties`, use an absolute keystore path, and never commit either file or credentials. Without `key.properties`, Gradle can create an unsigned release bundle for CI validation but it cannot be uploaded to Play.

Android property links route both cold and warm launches to the matching property; shared slug/ID URLs use the existing V1 API identifier. Android App Links are prepared for `https://dnbhomes.com/properties/*`. The website must publish `/.well-known/assetlinks.json` containing `com.nilebitlabs.dnbhomes` and the final Play signing certificate fingerprint before verified links work.

## Telemetry

Optional Sentry/PostHog configuration boundaries exist in `lib/core/telemetry`. Add the SDK packages and consent controls when production keys and privacy approval are available.

# Homes

Flutter consumer property application operated by dnb Homes.

The launcher, adaptive icon and splash retain the supplied black/white mark. The native V2 Home header uses the supplied theme-aware mark beside the HOMES consumer wordmark. The retired gradient W/roof assets remain removed.

V2 design scope, isolated test data, native checks and screenshots are recorded in
[the Android V2 QA record](docs/V2_ANDROID_QA.md).

## Local toolchain

Use Flutter 3.38.1 (Dart 3.10.0) and JDK 17, matching CI and the committed lockfile. Android builds compile and target API 36 (Android 16), meeting the [current Play target API requirement](https://developer.android.com/google/play/requirements/target-sdk). The toolchain requires SDK 36, NDK 27.0.12077973, AGP 8.12.1, Gradle 8.13 and Kotlin 2.2.0; the locked `share_plus 13.2.0` requires this build-tool baseline. Install dependencies with `flutter pub get --enforce-lockfile`. Gradle defaults to two workers with a 3 GB heap so it can run alongside the local stack; override those locally only when the machine has enough memory.

## Environments

```bash
flutter run --flavor development --dart-define=HOMES_ENV=development --dart-define=HOMES_API_URL=http://10.0.2.2:3000/api/v1
flutter build appbundle --release --flavor production --dart-define=HOMES_ENV=production --dart-define=HOMES_API_URL="$HOMES_API_URL"
```

For an Android emulator, use the development URL above. Forward the API port with `adb reverse tcp:3000 tcp:3000` so local demo media URLs (`localhost:3000`) also resolve on the device. For a USB device, use the same forwarding command and `HOMES_API_URL=http://127.0.0.1:3000/api/v1`.

Production API URLs, Sentry DSNs, and PostHog keys must be supplied using `--dart-define`; none are committed.

Validate with `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, a development `flutter build apk`, and the production `flutter build appbundle` command. A production bundle without a real upload keystore is only a build-validation artifact. Android pins DataStore 1.2.1 because the preferences dependency graph previously bundled a native counter with misaligned 16 KB RELRO segments. Check 64-bit native LOAD/RELRO alignment and APK ZIP alignment before release.

## Android signing

Create an upload keystore outside the repository. Copy `android/key.properties.example` to `android/key.properties`, use an absolute keystore path, and never commit either file or credentials. Normal production release tasks fail if `key.properties` or the upload keystore is missing. An explicit local validation profile can create an unsigned, non-runnable bundle for CI/native checks; it cannot be uploaded to Play.

Android property links route both cold and warm launches to the matching property; shared slug/ID URLs use the existing V1 API identifier. Android App Links are prepared for `https://dnbhomes.com/properties/*`. The website must publish `/.well-known/assetlinks.json` containing `com.nilebitlabs.dnbhomes` and the final Play signing certificate fingerprint before verified links work.

## Telemetry

Optional Sentry/PostHog configuration boundaries exist in `lib/core/telemetry`. Add the SDK packages and consent controls when production keys and privacy approval are available.


## Production release gate

Douglas must supply the actual `HOMES_API_URL` (public HTTPS `/api/v1` root); no API hostname is assumed. Production Gradle tasks require `HOMES_ENV=production` and reject omitted/localhost/reserved example/invalid hosts. Normal production release builds also require valid signing configuration. Dart startup independently checks the flavor/environment and endpoint and refuses unknown environments. The legacy `.env` file is no longer bundled; use dart defines and never put secrets into the consumer app.

To validate native release compilation without real production inputs or a keystore:

```bash
HOMES_BUILD_PROFILE=local flutter build appbundle --release --flavor production \
  --dart-define=HOMES_ENV=production \
  --dart-define=HOMES_API_URL=http://127.0.0.1:3000/api/v1 \
  --dart-define=HOMES_BUILD_VALIDATION=true
python3 scripts/check-android-bundle.py
```

This accepts loopback only, refuses any local keystore, produces an unsigned bundle, and embeds a marker that prevents startup/network use. It is a compilation artifact, never a release candidate. CI uses this profile without production secrets. For a real signed release, unset `HOMES_BUILD_PROFILE`, omit `HOMES_BUILD_VALIDATION`, configure the real API and upload key, then use the production build command above.

## Release inputs and device QA

Keep `com.nilebitlabs.dnbhomes` as the production application ID; development/staging suffixes isolate installs. `version: 1.0.0+1` is the starting version only: before Play upload confirm the existing Play app's identity and select a greater unused versionCode via `--build-number`. Store/signing credentials stay outside Git; the Play app signing certificate is distinct from the upload certificate. Supply its actual SHA-256 fingerprint to the website `ANDROID_APP_LINK_FINGERPRINTS` setting, then verify dnbhomes.com TLS/assetlinks and Android domain verification. Debug/development installs do not prove verified production App Links.

The merged release manifest requests INTERNET, ACCESS_NETWORK_STATE and the app-scoped AndroidX signature permission (no location/storage/camera permissions) and no blanket cleartext exception. R8/resource shrinking remain enabled with default and library consumer rules. Compile/target SDK 36 and native alignment checks meet the technical baseline, but test the signed release on physical devices including a real 16 KB device and Android 16 before launch. Play listing/privacy-policy URL, approved screenshots/content rating/Data safety declarations and any applicable developer verification/closed-testing requirements need the actual Play Console account. Complete those using verified product/legal facts; do not fabricate entries. Genuine listings/media and Douglas's contact details belong in Admin/production configuration, not a demo seed.

### Public preview APK

The staging flavor keeps its separate package ID and displays **Homes** on the
phone. To build the installable debug APK against the current preview API:

```sh
flutter build apk --debug --flavor staging \
  --dart-define=HOMES_ENV=staging \
  --dart-define=HOMES_API_URL=https://dnbhomesbackend.onrender.com/api/v1
```

Output: `build/app/outputs/flutter-apk/app-staging-debug.apk`. This debug artifact
can be transferred as a file to a phone; it uses the public API without USB or
shared Wi-Fi. Release signing and production safeguards remain unchanged.

For optimized phone testing, use the same command with `--profile` instead of
`--debug`. Its output is `build/app/outputs/flutter-apk/app-staging-profile.apk`.
This profile APK uses the Android Debug signing certificate and the same staging
application ID; it is a sideloaded test build, not a production Play release.

### Debug/profile provenance

Use `python3 scripts/build-staging-parity.py` to clean-build both staging modes
from one source fingerprint. It preserves SHA-labelled APKs and a manifest under
`build/staging-parity/`, including mode, byte size, SHA256, entrypoint and API.
Do not identify source freshness by the launcher label or version 1.0.0 alone.
The older 10 October hardening profile APK predates the compact-card commits;
it should not be compared against a newer debug APK. Clean debug/profile builds
of 6350274 rendered identical Discover card/control bounds on the same Android 9
emulator; there is no mode-specific property-card code. Repeat parity verification
after feature changes and preserve the new manifest alongside the APK you send.

Development-flavor native media permits HTTP only to localhost, 127.0.0.1 and the Android emulator host alias 10.0.2.2, for isolated local QA. This configuration is absent from staging and production; all other cleartext hosts remain blocked.

### Optional accounts and Discover Swipe

Guests can browse, save, compare and request viewings without signing in. Verified
consumer accounts synchronize Saved, Compare, recent properties and owned viewing
history with the Website through the consumer API. Signed session credentials live
in platform secure storage; retry queues contain public property IDs only. Guest
viewings can be claimed only with their original private ownership token.

Grid and Swipe share the current query and filters. Swipe uses vertical property
navigation and horizontal media navigation, retaining media position after opening
details. Only the active video allocates a player, starts on explicit muted play,
and pauses when backgrounded or leaving its route. Images use bounded decoding.
The test matrix covers phones/tablets, both themes and text scales up to 1.6.

iOS configuration targets iOS 13, uses private Keychain entitlements and keeps the
existing bundle identifier. Actual Xcode signing, iPhone playback and device QA
require a Mac and Apple hardware; Linux validation does not establish iOS release
readiness. Hosted verification/reset requires an authenticated email provider.

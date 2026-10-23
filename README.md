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

The app defaults to `https://homes-api.nilebitlabs.com/api/v1`. To use this hosted backend on a phone or emulator, run `flutter run --flavor development`. Use the explicit local URL above only when developing against a local backend. `HOMES_API_URL` can override the default using `--dart-define`; production builds still require it explicitly. Sentry DSNs and PostHog keys must also be supplied using `--dart-define`.

Validate with `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, a development `flutter build apk`, and the production `flutter build appbundle` command. A production bundle without a real upload keystore is only a build-validation artifact. Android pins DataStore 1.2.1 because the preferences dependency graph previously bundled a native counter with misaligned 16 KB RELRO segments. Check 64-bit native LOAD/RELRO alignment and APK ZIP alignment before release.

## Android signing

Create an upload keystore outside the repository. Copy `android/key.properties.example` to `android/key.properties`, use an absolute keystore path, and never commit either file or credentials. Normal production release tasks fail if `key.properties` or the upload keystore is missing. An explicit local validation profile can create an unsigned, non-runnable bundle for CI/native checks; it cannot be uploaded to Play.

Android property links route both cold and warm launches to the matching property; shared slug/ID URLs use the existing V1 API identifier. Android App Links are prepared for `https://dnbhomes.com/properties/*`. The website must publish `/.well-known/assetlinks.json` containing `com.nilebitlabs.dnbhomes` and the final Play signing certificate fingerprint before verified links work.

## Telemetry

Optional Sentry/PostHog configuration boundaries exist in `lib/core/telemetry`. Add the SDK packages and consent controls when production keys and privacy approval are available.


## Production release gate

For production builds, explicitly supply `HOMES_API_URL=https://homes-api.nilebitlabs.com/api/v1` (or the current public HTTPS `/api/v1` root). Production Gradle tasks require `HOMES_ENV=production` and reject omitted/localhost/reserved example/invalid hosts. Normal production release builds also require valid signing configuration. Dart startup independently checks the flavor/environment and endpoint and refuses unknown environments. The legacy `.env` file is no longer bundled; use dart defines and never put secrets into the consumer app. API addresses are compiled into each APK: changing `.env` or updating the backend does not change an already installed app. Rebuild and install the new APK after changing `HOMES_API_URL`; the custom API hostname is used to avoid the Render-hostname DNS failures observed on Wi-Fi.

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
  --dart-define=HOMES_API_URL=https://homes-api.nilebitlabs.com/api/v1
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

iOS configuration targets iOS 13, uses private Keychain entitlements with bundle identifier
`com.nilebitlabs.dnbhomes`. Actual Xcode signing, iPhone playback and device QA
require a Mac and Apple hardware; Linux validation does not establish iOS release
readiness. Hosted verification/reset requires an authenticated email provider.

### Consumer Google and Apple sign-in

Social providers are production capabilities, not baked credentials. The app renders Google/Apple actions only when the Backend capabilities endpoint reports that provider enabled and the matching build input is present.

Google:
- `HOMES_GOOGLE_WEB_CLIENT_ID` is the backend/server OAuth audience used by Android and iOS ID tokens.
- `HOMES_GOOGLE_IOS_CLIENT_ID` is the iOS OAuth client ID.
- Android must register both `com.nilebitlabs.dnbhomes` and the staging package with their actual signing certificate SHA-1/SHA-256 values in the Google project.
- iOS additionally requires the Google `REVERSED_CLIENT_ID` as Xcode build setting `HOMES_GOOGLE_REVERSED_CLIENT_ID`; `Info.plist` already references that build setting, so no source edit is required.

Apple:
- `HOMES_APPLE_SERVICE_ID` is the Apple Services ID used by Website/Android.
- `HOMES_APPLE_REDIRECT_URI` is the public HTTPS Backend callback, ending in `/api/v1/consumer/apple/callback/production` for production or `/staging` for staging.
- Native iOS uses bundle ID `com.nilebitlabs.dnbhomes`; Sign in with Apple entitlement is already present.
- The Backend validates both the Services ID and native bundle-ID audiences. Configure the Apple App ID/Services ID, domain/return URLs and server client-secret JWT externally.

A production Android build must include:
`--dart-define=HOMES_GOOGLE_WEB_CLIENT_ID=...`,
`--dart-define=HOMES_APPLE_SERVICE_ID=...` and
`--dart-define=HOMES_APPLE_REDIRECT_URI=...`.
A production iOS build additionally includes `--dart-define=HOMES_GOOGLE_IOS_CLIENT_ID=...` and the Xcode `HOMES_GOOGLE_REVERSED_CLIENT_ID` build setting. Release guards fail closed when these inputs are incomplete. Provider secrets/private keys never belong in the mobile app.

Same-email identities are not silently merged. If Google or Apple matches an existing Homes email, the user signs in with an already-connected method, then explicitly connects the provider from Security. Signed-in Saved, Compare, recent activity, viewing history/status and profile data remain server-synchronized; guest state is merged after authentication without claiming guest viewings unless their original secure ownership token is present.

## Release closeout and canonical links

Sharing now uses `HOMES_WEBSITE_URL`, defaulting to the actual hosted preview (`https://dnbhomeswebsite-psi.vercel.app`), rather than claiming the unpurchased domain is live. Android `HOMES_LINK_HOST` must match that origin at production build time. Set both to the purchased canonical domain later; no source edit is needed. Property links handle cold/warm launches, use the existing slug/ID API contract, and ordinary website access remains available. Website `ANDROID_APP_LINK_FINGERPRINTS` must use the **Play app signing** certificate, not the upload/debug certificate. Website `IOS_APP_LINK_TEAM_ID` enables the AASA property association only once a real Apple team exists.

The iOS bundle identifier is `com.nilebitlabs.dnbhomes`, display name Homes, deployment target 13.0. ATS has no insecure exception. No camera/photo/location permission is requested. Keychain storage uses this-device accessibility; plugin privacy manifests describe SDK required-reason API uses. The app privacy manifest describes optional account contact/identity, viewing content and synced discovery interactions used for functionality, with no tracking. Confirm the final aggregated Xcode privacy report and App Store Data Privacy questionnaire on macOS against configured providers before submission.

Xcode runs `scripts/validate-ios-release.py` before compiling a Release build: it requires production environment and explicit public HTTPS API/website URLs and refuses validation artifacts. Native Flutter deep linking is enabled; entitlements use `applinks:$(HOMES_LINK_HOST)` (actual preview by default). Set the Xcode `HOMES_LINK_HOST` build setting to the canonical domain before signing. There is no paid Apple team ID in Git. On macOS, use `flutter build ipa --release --dart-define=HOMES_ENV=production --dart-define=HOMES_API_URL="$HOMES_API_URL" --dart-define=HOMES_WEBSITE_URL="$HOMES_WEBSITE_URL"`; configure the real development team/signing/profile in Xcode. Linux tests validate repository config/guards; they do not prove an iOS build or physical Safari/iPhone behavior. H.264 MP4 is the broadly supported production video format; arbitrary WebM codec support is platform-dependent and fails gracefully.

One-time Douglas-controlled Android upload key, stored privately outside the repository:

```bash
mkdir -p "$HOME/.local/share/homes-signing"
chmod 700 "$HOME/.local/share/homes-signing"
keytool -genkeypair -v -keystore "$HOME/.local/share/homes-signing/homes-upload.jks" -alias homes-upload -keyalg RSA -keysize 3072 -validity 10000
```

Create ignored `android/key.properties` with `storeFile` (absolute keystore path), `storePassword`, `keyAlias=homes-upload`, and `keyPassword`; set its mode to 600 and keep an encrypted backup of the keystore/password. Never commit either file. Choose the next unused Play build number. With real public endpoints and signing configured:

```bash
export HOMES_API_URL=https://homes-api.nilebitlabs.com/api/v1
export HOMES_WEBSITE_URL=https://YOUR_CANONICAL_WEBSITE_HOST
export HOMES_LINK_HOST=YOUR_CANONICAL_WEBSITE_HOST
unset HOMES_BUILD_PROFILE
flutter build apk --release --flavor production --build-number=NEXT_UNUSED_INTEGER --dart-define=HOMES_ENV=production --dart-define=HOMES_API_URL="$HOMES_API_URL" --dart-define=HOMES_WEBSITE_URL="$HOMES_WEBSITE_URL"
flutter build appbundle --release --flavor production --build-number=NEXT_UNUSED_INTEGER --dart-define=HOMES_ENV=production --dart-define=HOMES_API_URL="$HOMES_API_URL" --dart-define=HOMES_WEBSITE_URL="$HOMES_WEBSITE_URL"
```

The placeholders above must be replaced with actual configuration; they are not active domain claims. Unsigned local validation AABs are intentionally non-runnable and unsuitable for distribution. CI checks all embedded ELF/ZIP alignment for 16-KB compatibility. Keep debug/profile phone QA separate from production signing.

### Approved startup brand loader

`lib/core/startup/startup_brand_loader.dart` is installed once in `HomesApp`'s
root builder. The underlying Navigator starts normally, preserving cold/warm
property deep links. The approved 4,080ms opening runs alongside local theme,
Saved/Compare/Viewings restoration, then fades out in 180ms. If local bootstrap
runs longer, it holds the completed composition without repainting or replaying.
Optional account network synchronization remains in the background; it does not
extend the splash. Navigation, property/media loading and all ordinary loading
indicators are unchanged. A single bounded controller is disposed with its startup boundary.

The supplied SVG strings are parsed directly (including the elliptical O arcs),
with cached PathMetrics and normalized 1.02-to-zero draw behavior. Flutter's SVG
arc parser normalizes arcs to cubic segments, a vector-platform representation
rather than a manual redraw. Timings, cubic curves, word transform, gap overlays,
settle origin and colors match the approved HTML. `disableAnimations` displays
the completed composition with a 150ms opacity fade, without stroke drawing.

The native launch bridge uses plain white / #1f1e20 backgrounds while Flutter
starts. Android 12+ uses a transparent launch icon so no static logo precedes the
animated signature loader. The animation starts at Flutter's first frame.
Native dark-mode resolution uses the OS theme until saved app preferences can
be restored. Rebuild the APK for native launch changes; hot reload is insufficient.

# Homes Android V2 visual QA

Design reference: website V2 `b0f9ce6fa5fa306e066b8a3f014d271b95e54782`.
Android base: `e23793d5e33b3bb8afd0a27556fd52a8f17cb8ff`.
Branch: `revamp/v2-android`. QA date: 9 October 2026.

## Scope

Website emerald/ivory and deliberate dark tokens, native Roboto hierarchy,
H./HOMES lockup, photographic Home, stronger search and intent controls,
image-first property cards, content-sized responsive Discover rows, grouped
filters, persistent detail viewing action, viewing context, quiet request status,
paired comparison values, lighter navigation and theme controls. Available API
image descriptions are exposed through image semantics; title/index descriptions
serve as fallbacks. Filter Apply is inset above the soft keyboard.

No new packages or remote fonts. IndexedStack, cached images, API contracts,
storage keys, routes, deep links, booking payload/time conversion, help/legal
content and Android release hardening remain intact. Two existing defects found
in QA were corrected: applying filters discarded district/amenities/hidden query
context, and the first recent search attempted to mutate an immutable empty list.

## Isolation

Native populated QA used the existing backend and seed script with 50
`demo:homes-v1` properties in a new, ephemeral MongoMemoryServer database named
`homes_development`, bound to loopback. App API: `10.0.2.2:3000/api/v1`;
`adb reverse tcp:3000 tcp:3000` resolved local media. Viewing submissions went
only to that local API. Empty inventory was tested by temporarily changing only
those local tagged properties to draft, then restoring published status. Outage
was simulated by pausing and resuming the local API process. No remote database,
production configuration or other repository source was changed.

## Automated verification

- Flutter 3.38.1 / Dart 3.10.0 / JDK 17; existing lockfile retained.
- `flutter pub get --enforce-lockfile`: pass.
- Format, analyze and `git diff --check`: see final validation record below.
- `flutter test`: 56 pass, including 32 populated layout scenarios covering
  360×800, 390×844, 412×915, 480×960, 600×960, 800×1280, 844×390 and 1024×600;
  each in light/dark at text scale 1.0/1.6. Scenarios exercise all four tabs,
  populated Saved/Viewings, comparison tray/screen, linked detail and viewing
  form. Device dimensions and pixel ratio are explicitly set in the tests.
- Filter round-trip/reset and first-search persistence have regression coverage.
  Four additional inset tests verify Apply remains above the keyboard in
  portrait/landscape at scale 1.0/1.6.
- Existing contract, config guard, booking, persistence, compact-state and
  cold/warm link tests remain green.

## Native checks

API 36 emulator; OpenGLES software rendering. Phone captures use 390×844 logical
dp (780×1688 physical pixels at density 320). Tablet captures use 800×1280 logical
dp (1600×2560 physical pixels). Native system font scale 1.6 was also inspected. The final debug APK was
reinstalled and the visible soft keyboard checked in both filters and the viewing
form; Apply remained above the keyboard. UI hierarchy inspection confirmed the
gallery image exposed the API alt description as an ImageView label.

The software-rendered API 36 emulator occasionally displayed a System UI ANR
on cold boot. Dismissing it with Wait restored the OS UI; Homes startup and
subsequent flows worked, with no Flutter runtime errors in the final native log.
Physical-device/TalkBack validation is still needed.

Verified startup, Home, Discover, purpose filtering, reset, price sorting,
photographic cards, cold and warm HTTPS property links, gallery swipe, favorite
and compare selection, two-property comparison, Back, pending viewing submission,
saved/viewing persistence after cold restart, Settings and all support/legal
routes, Light/Dark/System selection, outage and recovery, and honest empty Home.

Local request reference: `HOM-20261009-2FBE91`, pending. The confirmation and
persisted Viewings screen both displayed 10 October 2026, 10:00 AM on the emulator
configured for Africa/Kampala. This is local test evidence, not a production
request or promise of availability.

## Captures and local evidence

Outside product source/assets:
`/home/db/WORK/dnb Homes/artifacts/v2-android/`.

Required captures in `final/`:
- `home-390-light.png`, `home-390-dark.png`, `discover-390-light.png`
- `detail-390-light.png`, `detail-390-dark.png`, `filters-390-light.png`
- `saved-390-light.png`, `viewings-390-light.png`
- `home-800-tablet.png`, `discover-800-tablet.png`, `detail-800-tablet.png`

Additional captures include gallery, filters/search/compare/support in dark,
viewing form/confirmation, visible keyboard, persistence, large text, empty
inventory and outage/recovery in both themes.
Failed emulator/startup investigation captures are kept separately in
`diagnostics/`; they are not final visual evidence.

## Final build record

- Format: 41 files, zero changes; analyze: no issues; diff whitespace check: pass.
- Final tests: 56 pass in 19 seconds with the emulator stopped.
- Development debug APK: build pass; signed for local development. Debug startup
  was restored by cleaning generated build files and doing a fresh emulator
  install. No SDK, manifest, signing or application configuration change was
  needed. Profile startup had already succeeded.
- Required development APK command (default release): build pass, 56.2 MB.
  This artifact is unsigned when no release key is present and cannot be
  installed as-is; the existing signing behavior is intentionally preserved.
- Final production validation AAB: pass, 47.4 MB, unsigned and non-runnable.
  Native verifier: API 36, no bundled environment file, six 64-bit libraries
  with compatible 16 KB LOAD/RELRO layout. Development release APK zip alignment
  check (`zipalign -c -P 16 4`): pass.

One concurrent validation attempt timed out under host memory exhaustion with
an emulator and Gradle daemons active. The repeat was run sequentially and passed;
that failed attempt is not counted as successful test evidence.

## Release boundaries

These are development and validation artifacts, not a Play release. A real
production release still needs the upload keystore and an explicit public HTTPS
API. Genuine published production inventory and physical-device/TalkBack QA
remain separate launch requirements. No Play publishing or main merge occurred.

# Final release hardening

Property cards reserve identical text-scaled price/title/facts/verification slots, keeping the Verified badge visible without changing height. Geometry tests cover mixed land/room/apartment/commercial cards, five viewport sizes, both themes and text scales 1/1.6.

Mixed-media property detail uses lazy PageView construction with total counts and bounded image decoding (1400 pixel cache width). Videos create a controller only after Play and only for the active item. Native controls support seek/pause/retry; backgrounding or a route change pauses playback, media navigation disposes controllers, and fullscreen/back restores detail without forcing orientation. No autoplay or five simultaneous video decoders.

Viewing creation stores its opaque status token. Header/pull refresh fetch actual server status via X-Viewing-Token, updates status/schedule and persists the copy with guest email/phone removed. Failed refresh keeps the saved record; legacy entries show that live sync is unavailable. Only future pending/confirmed requests stay Upcoming; rejected/cancelled/completed/no_show move to Past. Matching backend hardening must be deployed first. Never authorize a viewing by reference alone or backfill legacy tokens insecurely.

Discover explicit/pull refresh bypasses the existing 30-second cache. Detail refresh fetches current server media/price/status while preserving content during loading/failure. Saved reloads stored IDs against current server records, keeps old data on network failure and hides unavailable archived records without deleting saved IDs. Existing Home refresh/coalescing remains; Settings/Compare stay local.

Staging sideload builds display Homes and use the public HTTPS preview API, requiring neither USB nor shared Wi-Fi:

```sh
flutter build apk --debug --flavor staging --dart-define=HOMES_ENV=staging --dart-define=HOMES_API_URL=https://dnbhomesbackend.onrender.com/api/v1
flutter build apk --profile --flavor staging --dart-define=HOMES_ENV=staging --dart-define=HOMES_API_URL=https://dnbhomesbackend.onrender.com/api/v1
```

Use profile for realistic optimized phone testing. Both are staging test artifacts, not signed production Play releases. Keep signing, HTTPS and production environment guards intact. Development emulator QA may use a disposable local API but uses the same owned HTTPS QA media; native cleartext protection is not weakened.

Validate locked dependencies, dart format, flutter analyze/test, both staging APK builds and git diff --check. Native media/back checks require API28 and API36. Hosted QA uses only the existing clearly labelled unverified 6aca1225ca3d4ce6f2209da4 record with owned synthetic media; its Render local uploads are temporary and not durable launch storage. Emulator timings do not establish physical-device performance or hide Render cold-start latency.

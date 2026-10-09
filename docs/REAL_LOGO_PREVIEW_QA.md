# Supplied logo and populated preview QA

9 October 2026; base main `4fac6f6be08a5c7ab2016bc3f1750b5b750bacba`, branch
`brand/real-logo`.

The Home lockup renders the supplied dark-on-light or pale-on-dark SVG through
existing flutter_svg, with preserved aspect ratio beside HOMES. No new package
was added. Existing supplied launcher and splash assets and native resources
are retained. The staging display label is **Homes**, as explicitly requested;
its separate package ID, flavor, deep links, signing and release guards remain
unchanged.

Enforced-lockfile pub get, format, analyze and 62 tests passed. The signed debug
staging APK was rebuilt against `https://dnbhomesbackend.onrender.com/api/v1`.
Aapt confirmed application-label Homes, ID com.nilebitlabs.dnbhomes.staging,
version 1.0.0+1 and min SDK 24; the debug build installed on API36 and the optimized profile build installed
successfully on Android 9/API28. Physical-device installation and accessibility
remain to verify.

Native 390x844 logical-dp inspection used the actual public preview API with its
50 published, unverified Uganda showcase listings. Verified Home mark in both
themes, Discover 50 results, rent 28/sale 16/short stay 6/land 8, filter clear/apply,
Ntinda search, a two-image detail gallery, Save, two-property Compare, viewing
submission/pending confirmation and device-local viewing persistence. No Flutter
runtime error appeared in the final native log. A cold-boot System UI ANR was
dismissed with Wait before QA; this is an emulator limitation.

Disposable preview request HOM-20261009-A7BD09 was confirmed pending in the
exact homes_preview database, with requested Uganda 10 October 2026 10:00 AM
stored as 07:00 UTC. Only that named QA request was removed after verification.
No production data or genuine viewing request was touched. Native screenshots are outside product assets in
`artifacts/showcase-real-logo/android/`.

## Screenshot defects and loading hardening

The old APK screenshots exposed a current defect: Home category shortcuts push
Discover outside the tab shell, leaving its ChoiceChip/InputChip controls without
Material. Discover now owns its Scaffold. A regression test reproduces that exact
navigation and chip removal in isolation. Filter requests also discard responses
from older queries so fast category changes cannot display the wrong inventory.

Tabs initialize on first visit and retain their state. Public listing queries share
in-flight requests and a bounded 30-second cache; explicit Home refresh bypasses
that cache. Property details remain fresh. Tests cover expiry, distinct queries,
refresh, failures, eviction and late responses. Bounded recommendation carousels
size to their contents instead of reserving oversized fixed-height card space.
Existing light/dark, small-screen and enlarged-text layout checks remain green.
The final optimized profile APK also installed and launched on Android 9/API28;
Home → Land returned eight plots without Material errors, the content-height
carousel was inspected, and current Home themes, 50-result Discover and detail
screens were captured against the public API.

The same 17 licensed photographs were resized without enlargement to at most
1280 pixels and encoded as JPEG quality 82, reducing their combined transfer size
from 51,475,408 to 2,922,043 bytes (94%). No photograph was generated or replaced.
Both public-HTTPS staging debug and profile APK builds passed; profile is an
optimized testing build signed by the same Android Debug certificate, not a Play
release. Aapt confirms its label Homes, unchanged staging ID and min SDK 24.

Render preview photos currently use ephemeral disk. The current free service
sleeps after 15 minutes idle, takes about a minute to wake, and loses local uploads
on spin-down, restart or redeploy. These infrastructure limitations cannot be
fixed by client caching. Durable media storage and an appropriate hosting plan are
required before launch (https://render.com/docs/free). Showcase inventory does not establish actual property
availability. Real release signing and phone/TalkBack checks remain separate.

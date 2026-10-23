# Android version 1.0.0 (build 1)

Production application ID: `com.nilebitlabs.dnbhomes`; API: `https://homes-api.nilebitlabs.com/api/v1`; website/App Link host: `dnbhomeswebsite-psi.vercel.app`. The signed production APK installs separately from the earlier `.staging` package. Version 1 artifacts are preserved in the private `DouglasBagambe/dnbhomesartifacts` release, with hashes and a source fingerprint.

This version includes the premium Home/Discover/Saved/Account navigation, Grid and retained Swipe discovery, Tours with vertical property and horizontal media browsing, availability badges/viewing restrictions, Compare zero/one/two/error states, skeleton content loading, a reduced-motion-aware DNB symbol loader, and the simplified Settings hierarchy. Share/contact actions handle unavailable external applications.

Android reads public support contacts and public OAuth client identifiers from the API capabilities endpoint. Provider secrets remain server-side. Configure the real support contacts and Google/Apple credentials on the backend when ready; no Android rebuild is required for these values. Unconfigured provider buttons remain unavailable. Actual identity-provider consent/sign-in and email delivery require the real external accounts; preparing integration code does not validate owner credentials or paid services. iOS still needs native identifier/URL-scheme/entitlement setup.

The upload key is outside the repository. Preserve its private keystore and password in a separate secure backup before changing computers. The public certificate is included in the recovery release. Google Play App Signing uses a separate signing certificate; register that certificate with Google OAuth and website App Links once available.

Reproduce the build with the commands in the recovery repository’s `RESTORE.md`. Use `python3 scripts/check-android-bundle.py --signed` to check a signed AAB; the default mode remains the unsigned QA validator. Native code and Java plugins target API 36 and the native validator checks 16 KB-compatible 64-bit LOAD/RELRO segments.

Recorded checks: 178 Flutter tests, clean analyzer, and 67 backend tests with exact-commit GitHub CI. Native checks and artifact checks are detailed in the private release report. Physical phone/Play internal-track acceptance, store listing, privacy/data declarations and real provider activation remain release gates. This document does not claim zero defects or Google Play approval.

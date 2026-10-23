# Mobile Tours and availability handoff

## Navigation and media

Mobile navigation is Home / Discover / Saved / Account. Discover retains both Grid and Swipe, including its existing filters and swipe-position behavior. Home's video-library action and Tours card open Tours as a separate full-screen route. Viewings, recent history, comparison, settings and support live under Account; existing authentication remains in place.

Tours pages vertically between properties and horizontally between each property's media. Only published properties with a valid HTTPS video qualify. Every property starts with its videos, followed by its images; duplicate media URLs and property IDs are removed. Returning to a property retains its horizontal position while it remains in the session. This is property discovery, not social posting: no invented engagement counts, comments or popularity metrics.

The existing public catalogue API supplies Tours. It uses popular ordering, shuffles each newly appended batch, scans up to four pages of 50 listings per request cycle and offers a continuation action for sparse video inventory. Location filters send both area and district. Location choices come from the real scanned inventory, not a complete national directory. A dedicated server-side video feed can replace this source later for a much larger catalogue.

Only the visible video owns an active decoder. Videos start muted, loop, and support pause and scrub. Moving offscreen, opening details, opening the location sheet, sharing or backgrounding releases playback. Returning restores position and preserves a manual pause while that media widget remains mounted. Failed or unsupported videos offer retry and keep navigation usable. Video initialization is bounded to 20 seconds and cancelled when the page is left. Video rendering contains the original aspect ratio so landscape room footage is not cropped. A dimmed, blurred property cover fills the unused space; photos use their own blurred backdrop. The background uses a low-resolution static image with a calm green fallback, not another playing video or decoder. On-screen controls remain light for contrast, while the location sheet follows the selected application theme. Compact metadata scrolls independently at enlarged text sizes; landscape keeps the central swipe area clear. Use broadly supported MP4/H.264 + AAC media; mobile code does not transcode uploads or guarantee every codec/device combination.

## Availability contract for the later Admin/backend pass

Public property list and detail responses should supply an optional, independent field:

```json
{ "availabilityStatus": "available" }
```

Supported values: `available`, `reserved`, `rented`, `sold`, `unavailable`.

This is independent of publication `status` (draft, pending_review, published, archived). Never use publication status to represent rental/sale availability.

- Missing/null/empty legacy field: preserve existing behavior and show no invented availability badge.
- `available`: show Available; allow viewing requests for public properties.
- Other supported values: show the corresponding label; disable viewing requests.
- Unknown nonempty values: show Unavailable and disable requests.
- Archived, draft and pending-review properties cannot request viewings even if marked available.
- A 404 during detail refresh disables the existing preview's viewing action.

The mobile cards, Tours metadata, property details and viewing form already consume this field. Admin must manage it and backend must validate allowed values, return it consistently in both lists and details, and enforce availability atomically when receiving a viewing request. Mobile disabling is a user experience guard, not an authorization or booking constraint. Availability can change after a screen loads; request-time enforcement belongs on the server. Changing the agreed field or enum later will require a mobile update.

No Admin, website, backend, storage, DNS or contact/provider credentials are modified by this mobile pass. The app keeps `https://homes-api.nilebitlabs.com/api/v1`.

## Verification

Automated tests cover feed pagination, sparse inventories, deduplication, location request races, retry, availability compatibility, decoder lifecycle, late initialization, nested swipe gestures and route coverage. Layout coverage includes phone/tablet, light/dark themes, landscape and enlarged text. Emulator checks and APK evidence are recorded with the built artifact. A physical-device Wi-Fi/mobile-data and codec playback check remains part of release acceptance; emulator/widget checks cannot substitute for all phone hardware.

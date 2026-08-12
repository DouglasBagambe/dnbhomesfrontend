# Homes Android visual audit

Audited against the August 2026 Homes web design specification. This is an audit only; no Flutter UI was changed.

## Home — MINOR REVISION

The screen is already property-first: it uses live photography, a compact logo bar, image hero carousel, search entry, horizontal listing rails and inventory-derived locations. It feels materially closer to a marketplace than a dashboard. Revise the brand green from `#176B48` to `#0B8A57`, reduce the 28px hero/card radius toward the 14–18px system, rename sections to match the quieter web hierarchy, and verify that the header uses the clean production mark rather than the large converted dark/light raster-like SVG variants. Empty inventory currently removes the hero entirely; a deliberate compact state is needed.

## Discover — MINOR REVISION

The pinned title, purpose chips, filter access, actual total count, infinite loading and property cards provide a strong native marketplace flow. Align chip, control and card radii with the specification, ensure result cards prioritize price before secondary metadata, and reduce any bordered-card treatment that makes results feel like form panels.

## Property Details — MINOR REVISION

The screen has photography, price, facts, viewing CTA, real contact controls, description, amenities and location in the correct content order. Improve the gallery into a more deliberate multi-image composition on tablets, make representative/safety content visually quieter, align the primary green and 10px button radius, and keep price visually stronger than descriptive copy.

## Favorites — MINOR REVISION

The local-device behavior and honest empty state are correct, and saved properties reuse the marketplace card. Rename the heading from “Favorites” to “Saved homes,” revise the empty-state copy to “Save homes you want to come back to,” and ensure the state remains compact rather than vertically dominant.

## Bookings — MINOR REVISION

The two-tab pending/history model, local-storage disclosure and status chips are useful and truthful. Rename the top-level heading to “Viewing requests,” present requests as lighter timeline-style consumer cards, and reduce the visual resemblance to a management list.

## Search / Filters — PASS

Debounced API search, recent searches, real result cards, popular locations, shareable Discover handoff and purpose/type filtering are appropriate. The main revision is token alignment: green, button radius, input radius and slightly quieter chips.

## Navigation — PASS

Four clear destinations—Home, Discover, Favorites and Bookings—match core consumer intent and use standard native navigation. Consider changing “Favorites” to “Saved” for cross-platform language consistency. The compare action appears only when meaningful and is not a permanent distraction.

## Cross-cutting findings

- **Branding:** MINOR REVISION — real logo assets are used, but the home top bar appears to use the complex converted light/dark logo instead of the simpler mark.
- **Colors:** MINOR REVISION — current green is `#176B48`; align functional green to `#0B8A57` in the controlled Android design pass.
- **Typography:** MINOR REVISION — hierarchy is good, but Roboto and frequent weight 700 feel heavier than the web specification’s 600-weight headings. Keep native typography if desired, but reduce visual weight.
- **Property imagery:** PASS — imagery drives the home, listing cards and details.
- **Cards:** MINOR REVISION — 20–28px radii and outlined Material cards are softer/heavier than the specified 14px photography-led treatment.
- **Buttons:** MINOR REVISION — 52px height is accessible; align radius to 10px and avoid excessive 700 weight.
- **Spacing:** PASS — dense enough for a mobile marketplace with no obvious desktop-style dead space.
- **Empty states:** MINOR REVISION — semantically honest; revise copy and constrain vertical footprint where `SliverFillRemaining` makes failures dominate.
- **Overall marketplace feel:** MINOR REVISION — recognizably a property product already. A controlled token/card/empty-state alignment pass is warranted, not a major rewrite.

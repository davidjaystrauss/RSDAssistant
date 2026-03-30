# RSD Assistant

`RSD Assistant` is an iPhone, iPad, and Mac Catalyst app for browsing Record Store Day release lists, building a wishlist, tracking release status, previewing music, and planning a store run with a built-in participating-stores map.

## Current App Scope

The app currently supports:

- release browsing in `list`, `grid`, and `cover flow`
- immersive landscape cover flow on iPhone and iPad
- locale-aware default selection of the active `2026` regional list, falling back to Canada
- search, sort, reverse sort, and filter controls
- wishlist saved per list, with manual reordering
- global wishlist browsing across all bundled countries/lists
- wishlist export as branded `PDF`, `CSV`, and plain text
- release status tracking with `Got It` and `No Luck`
- Apple Music metadata/artwork enrichment where available
- improved release detail tracklist parsing and display
- full-screen participating-stores map with search, selected-store persistence, and directions
- iCloud key-value sync for wishlist order, statuses, and selected store
- home screen quick actions for `Wishlist` and `Participating Stores`

## Bundled Data

### Release Files

Canonical release JSON lives in [data/releases](/Users/davidstrauss/Documents/RSD%20Helper/data/releases).

Current bundled/app-available data includes:

- legacy bundled lists: `2017`, `2018`, `2017 Black Friday`, `2019 Black Friday`
- archive backfills: `2020` through `2025` across US, Canada, UK, Germany, Australia, and Italy where available
- active regional 2026 lists:
  - `2026 - US`
  - `2026 - Australia`
  - `2026 - Canada`
  - `2026 - Germany`
  - `2026 - UK`

Recent 2026 data work includes:

- expanded AU coverage from the broader AU PDF source
- structured AU variant/category parsing
- UK and Germany Apple Music/artwork enrichment improvements

### Store Files

Participating store data is bundled from [data/stores-2026.json](/Users/davidstrauss/Documents/RSD%20Helper/data/stores-2026.json).

Current bundled store count: `2695`

Current country coverage includes:

- United States of America: `1895`
- United Kingdom: `302`
- Canada: `209`
- Germany: `185`
- Hong Kong: `31`
- Austria: `29`
- Schweiz: `27`
- Poland: `10`
- Ireland: `7`

## Project Structure

- [RSD Helper](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper)
  Main app target.
- [data/releases](/Users/davidstrauss/Documents/RSD%20Helper/data/releases)
  Canonical release JSON files.
- [data/stores-2026.json](/Users/davidstrauss/Documents/RSD%20Helper/data/stores-2026.json)
  Canonical bundled store dataset.
- [data/archive_sources](/Users/davidstrauss/Documents/RSD%20Helper/data/archive_sources)
  Source PDFs and raw archive inputs.
- [data/archive_manifests](/Users/davidstrauss/Documents/RSD%20Helper/data/archive_manifests)
  Archive import manifests.
- [scripts](/Users/davidstrauss/Documents/RSD%20Helper/scripts)
  Import, validation, and enrichment tooling.
- [docs](/Users/davidstrauss/Documents/RSD%20Helper/docs)
  Branding/icon experiments and project notes.

## Key App Files

- [RSDViewController.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDViewController.swift)
  Main releases shell, theming, filtering, cover flow, launch overlay, and app state.
- [RSDFavoritesViewController.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDFavoritesViewController.swift)
  Wishlist UI, global wishlist view, reordering, export generation, and PDF layout.
- [RSDDetailViewController.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDDetailViewController.swift)
  Release detail screen, tracklist rendering, preview actions, and status controls.
- [RSDStoreMapViewController.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDStoreMapViewController.swift)
  Stores map, visible-stores list, selected-store handling, and directions flow.
- [ParticipatingStores.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/ParticipatingStores.swift)
  Store models, bundled loading, coordinate cache, and selected-store persistence.
- [Listing.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/Listing.swift)
  Canonical release model and list/filter helpers.

## Build / Run

The app is configured as an Xcode project.

Open:

- [RSD Helper.xcodeproj](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper.xcodeproj)

Then:

1. Open the project in Xcode.
2. Select the `RSD Helper` target.
3. Build and run on iPhone, iPad, or Mac Catalyst.

Recommended environment:

- Xcode 16 or newer
- macOS with `xcrun` available
- `pdftotext` installed for PDF/archive import workflows
- an Apple Music developer token for enrichment runs

## iCloud

Wishlist order, release statuses, and selected store use `NSUbiquitousKeyValueStore`.

Device sync requires the app’s iCloud capability to be enabled in:

- Apple Developer App ID settings
- Xcode `Signing & Capabilities`

Specifically:

- enable `iCloud`
- enable `Key-value storage`

## Data / Import Scripts

Core scripts:

- [scripts/import_rsd_2026.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_rsd_2026.py)
  Imports current-year lists, including AU PDF support and structured AU metadata extraction.
- [scripts/import_archive_pdfs.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_archive_pdfs.py)
  Imports archived PDFs into canonical JSON.
- [scripts/enrich_with_apple_music.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/enrich_with_apple_music.py)
  Enriches release files with Apple Music matches and artwork metadata.
- [scripts/import_stores_2026.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_stores_2026.py)
  Imports the main 2026 store dataset.
- [scripts/import_store_locators.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_store_locators.py)
  Pulls additional international store-locator data into canonical store JSON.
- [scripts/validate_release_json.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/validate_release_json.py)
  Validates canonical release documents.
- [scripts/convert_legacy_release_json.py](/Users/davidstrauss/Documents/RSD%20Helper/scripts/convert_legacy_release_json.py)
  Converts older app-era JSON files into the canonical schema.

Typical workflow:

1. Import or regenerate a release JSON file from source PDFs/pages.
2. Validate the output.
3. Run Apple Music enrichment with a storefront-specific token.
4. Bundle the generated JSON into the Xcode target.

Apple Music enrichment requires:

- `APPLE_MUSIC_DEVELOPER_TOKEN`

Typical storefront values:

- `us`
- `ca`
- `gb`
- `de`
- `au`

## Branding / UI

Current branding work includes:

- country/event-specific themes
- branded wishlist PDF exports
- record-based launch/brand treatment
- ongoing icon exploration in [docs/icon-concepts](/Users/davidstrauss/Documents/RSD%20Helper/docs/icon-concepts)

Related files:

- [docs/branding-system.md](/Users/davidstrauss/Documents/RSD%20Helper/docs/branding-system.md)
- [docs/icon-concepts](/Users/davidstrauss/Documents/RSD%20Helper/docs/icon-concepts)
- [RSD Helper/RCA.TTF](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RCA.TTF)

## Known Caveats

- Archive/backfill quality still varies by country and year because source PDFs and pages differ substantially.
- Some older archive files are present on disk even if they are not currently surfaced in the in-app picker.
- Store hours/open-closed status are not part of the bundled store dataset.
- The local Xcode environment on this machine has shown simulator/runtime noise unrelated to Swift source compilation.
- There is still a small first-load release-list jump that has not yet been isolated cleanly.

## Short-Term Next Work

- continue improving weaker archive/import families only where it materially improves shipped data quality
- finalize production icon asset replacement from the approved record concept
- continue expanding and correcting participating-store coverage
- add more direct share/export options from release detail and stores surfaces
- run a final accessibility and layout pass across iPhone, iPad, and Mac Catalyst

## License / Ownership

This repository contains application code by David Strauss and imported third-party source trees with their own licenses and readmes. Review vendored library folders before redistributing those components separately.

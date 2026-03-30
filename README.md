# RSD Assistant

`RSD Assistant` is an iPhone/iPad/Catalyst app for browsing Record Store Day release lists, saving favorites, previewing music, and planning a store run with a built-in participating-store map.

The project now includes:

- bundled canonical JSON release data
- offline import/enrichment scripts for new yearly lists
- a participating-store map with favorite-store persistence
- favorites export as a printable PDF checklist/table
- list theming by country/event

## Current Scope

The app currently supports:

- release browsing in `list`, `grid`, and `cover flow`
- grid as the default first-run releases layout
- locale-aware default selection of the active `2026` regional list, falling back to Canada
- search, sort, reverse sort, and filter controls
- favorites saved per active list
- home screen quick actions for `Favorites` and `Participating Stores`
- Apple Music plus secondary preview links from the detail screen
- prioritized artwork loading when a detail screen is opened before cover art has loaded
- a full-screen stores map with floating list, search, and favorite-store selection
- iCloud key-value sync for favorites and selected store
- PDF export of favorites with artwork and event/store header

## Data In Repo

### Release Files

Canonical release JSON lives in [`data/releases`](/Users/davidstrauss/Documents/RSD%20Helper/data/releases).

Current archive and active data files on disk include:

- legacy bundled lists: `2017`, `2018`, `2017 Black Friday`, `2019 Black Friday`
- archive backfills: `2020` through `2025` across US, Canada, UK, Germany, Australia, and Italy where available
- active regional 2026 lists:
  - `2026 - US`
  - `2026 - Australia`
  - `2026 - Canada`
  - `2026 - Germany`
  - `2026 - UK`

These archive and active files are now bundled into the app picker.

### Store Files

Participating store data is bundled from [`data/stores-2026.json`](/Users/davidstrauss/Documents/RSD%20Helper/data/stores-2026.json).

Current bundled store count: `2695`

Country coverage currently includes:

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

- [`RSD Helper`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper)
  The app target.
- [`data/releases`](/Users/davidstrauss/Documents/RSD%20Helper/data/releases)
  Canonical release JSON files.
- [`data/archive_sources`](/Users/davidstrauss/Documents/RSD%20Helper/data/archive_sources)
  Source PDFs and raw archive inputs.
- [`data/archive_manifests`](/Users/davidstrauss/Documents/RSD%20Helper/data/archive_manifests)
  Manifest files for archive imports.
- [`data/stores-2026.json`](/Users/davidstrauss/Documents/RSD%20Helper/data/stores-2026.json)
  Canonical bundled store dataset.
- [`scripts`](/Users/davidstrauss/Documents/RSD%20Helper/scripts)
  Import, validation, and enrichment tooling.
- [`docs`](/Users/davidstrauss/Documents/RSD%20Helper/docs)
  Data notes, branding/icon experiments, and design docs.

## Key App Files

- [`RSDViewController.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDViewController.swift)
  Main releases shell, list selection, theming, filtering, favorites sheet, and app state.
- [`RSDFavoritesViewController.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDFavoritesViewController.swift)
  Favorites UI plus PDF export generation.
- [`RSDStoreMapViewController.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDStoreMapViewController.swift)
  Full-screen stores map, floating visible-stores list, and favorite-store selection.
- [`ParticipatingStores.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/ParticipatingStores.swift)
  Store models, bundled loading, resolved-coordinate cache, and selected-store persistence.
- [`Listing.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/Listing.swift)
  Canonical release model and filter/sort helpers.
- [`RSDDetailViewController.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDDetailViewController.swift)
  Release detail screen and preview actions.

## Build Requirements

- Xcode 16 or newer is recommended
- macOS with `xcrun` available
- `pdftotext` installed for the archive/PDF import scripts
- an Apple Music developer token for enrichment runs

The app is configured as an Xcode project, not an SPM-only app package.

Open:

- [`RSD Helper.xcodeproj`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper.xcodeproj)

## Running The App

1. Open [`RSD Helper.xcodeproj`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper.xcodeproj) in Xcode.
2. Select the `RSD Helper` target.
3. Build and run on iPhone, iPad, or Mac Catalyst.

### iCloud

Favorites and selected-store sync use `NSUbiquitousKeyValueStore`.

The code is already in place, but device sync requires the app’s iCloud capability to be enabled in:

- Apple Developer App ID settings
- Xcode `Signing & Capabilities`

Specifically:

- enable `iCloud`
- enable `Key-value storage`

## Data / Import Scripts

### Core Scripts

- [`scripts/import_rsd_2026.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_rsd_2026.py)
  Imports current-year lists, including PDF-driven US 2026.
- [`scripts/import_archive_pdfs.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_archive_pdfs.py)
  Imports archived PDFs into canonical JSON.
- [`scripts/enrich_with_apple_music.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/enrich_with_apple_music.py)
  Enriches release files with Apple Music matches and artwork metadata.
- [`scripts/import_stores_2026.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_stores_2026.py)
  Imports the main 2026 store dataset.
- [`scripts/import_store_locators.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/import_store_locators.py)
  Pulls additional international store-locator data into canonical store JSON.
- [`scripts/validate_release_json.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/validate_release_json.py)
  Validates canonical release documents.
- [`scripts/convert_legacy_release_json.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/convert_legacy_release_json.py)
  Converts old app-era JSON files into the canonical schema.

### Example Workflow

1. Import or regenerate a release JSON file from source PDFs/pages.
2. Validate the output.
3. Run Apple Music enrichment with a storefront-specific token.
4. Bundle the generated JSON into the Xcode target.

### Apple Music Enrichment

Set:

- `APPLE_MUSIC_DEVELOPER_TOKEN`

Then run [`scripts/enrich_with_apple_music.py`](/Users/davidstrauss/Documents/RSD%20Helper/scripts/enrich_with_apple_music.py) against a canonical release file.

Regional storefronts matter. Typical storefront examples:

- `us`
- `ca`
- `gb`
- `de`
- `au`

## Theming / Branding

The app theme changes by list/event in [`RSDViewController.swift`](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDViewController.swift).

Current theme directions include:

- country-specific palettes
- Black Friday light and dark variants
- matching PDF export accents

Branding and icon exploration lives in:

- [`docs/branding-system.md`](/Users/davidstrauss/Documents/RSD%20Helper/docs/branding-system.md)
- [`docs/RSDIcon.icon`](/Users/davidstrauss/Documents/RSD%20Helper/docs/RSDIcon.icon)
- [`docs/RSD-record-only.svg`](/Users/davidstrauss/Documents/RSD%20Helper/docs/RSD-record-only.svg)
- [`docs/icon-example-record-bag-us.svg`](/Users/davidstrauss/Documents/RSD%20Helper/docs/icon-example-record-bag-us.svg)
- [`docs/icon-example-record-bag-canada.svg`](/Users/davidstrauss/Documents/RSD%20Helper/docs/icon-example-record-bag-canada.svg)
- [`docs/icon-example-record-bag-black-friday.svg`](/Users/davidstrauss/Documents/RSD%20Helper/docs/icon-example-record-bag-black-friday.svg)

## Known Caveats

- Archive backfill quality is uneven across countries/years because PDF layouts differ substantially.
- Germany archive imports are improved but still contain some wrapped-row edge cases, especially in longer 2024/2025 entries.
- Some archive files on disk are enriched/generated even if they are not yet surfaced in the app picker.
- Store hours and open/closed status are not currently in the bundled store dataset.
- The local Xcode environment on this machine has shown simulator/runtime noise unrelated to Swift source compilation.

## Next Logical Work

- continue improving the weaker archive families only where it materially improves match quality
- finalize the remaining launch/static brand asset pipeline and remove stale legacy asset copies
- continue expanding international store coverage
- adopt Tahoe / iOS 26 visual APIs after the current baseline is committed

## TODO

- add a `Share Release` action from the detail screen
- add `Copy Address` / explicit map-app choices from the participating stores UI
- add a one-tap `Reset filters and sort` action in releases
- add a `Favorites first` or `Hide favorited` browsing mode for the main releases list
- improve empty states for filtered stores and empty-search results
- add app-string localization infrastructure (`Localizable.strings` / localized SwiftUI strings)
- localize core app chrome for list browsing, favorites, stores, export, and settings surfaces
- run a final accessibility pass for Dynamic Type, VoiceOver labels, and contrast
- add explicit accessibility labels/hints for custom controls, cover flow, map controls, and placeholder art
- run a final resize/layout pass on iPhone, iPad, and Mac Catalyst across list, grid, and cover flow

## License / Ownership

This repository contains application code by David Strauss and imported third-party source trees with their own licenses and readmes. Review the vendored library folders before redistributing those components separately.

# Release Data

## Current State

The app currently reads a hardcoded bundled JSON file in [RSDViewController.swift](/Users/davidstrauss/Documents/RSD%20Helper/RSD%20Helper/RSDViewController.swift) using manual dictionary parsing:

- File name is hardcoded to `rsdbf2019.json`
- JSON keys use mixed legacy names like `Artist` and `More Info`
- Parsing is force-unwrapped and not versioned
- Music provider identifiers are not stored
- The app has no validation step before shipping a yearly list

## Goal

Move to a canonical, versioned release schema that:

- can be generated from a scrape/import pipeline
- can be validated before bundling into the app
- leaves room for Apple Music and Spotify identifiers
- can still be converted from legacy `rsd*.json` files

## Canonical Schema

Top-level document:

```json
{
  "schemaVersion": 1,
  "event": {
    "slug": "rsd-2026",
    "name": "Record Store Day 2026",
    "kind": "main",
    "releaseDate": "2026-04-18"
  },
  "releases": [
    {
      "id": "artist-title-format-label",
      "artist": "Example Artist",
      "title": "Example Title",
      "format": "LP",
      "label": "Example Label",
      "quantity": "1500",
      "details": "Long description from Record Store Day.",
      "imageURL": "https://recordstoreday.com/Photo/123456789:360",
      "sourceURL": "https://recordstoreday.com/SpecialRelease/12345",
      "releaseType": "exclusive",
      "appleMusic": {
        "albumID": null,
        "albumURL": null,
        "artistName": null,
        "artistURL": null,
        "artwork": {
          "urlTemplate": null,
          "width": null,
          "height": null,
          "bgColor": null,
          "textColor1": null,
          "textColor2": null,
          "textColor3": null,
          "textColor4": null
        }
      },
      "spotify": {
        "albumURL": null,
        "albumID": null
      }
    }
  ]
}
```

## Field Notes

- `schemaVersion`: Increment only when the file structure changes.
- `event.slug`: Stable identifier used for bundled file naming and caching.
- `event.kind`: Suggested values: `main`, `black-friday`, `drop`, `regional`.
- `id`: Deterministic slug, unique within the file. It should include `format` so CD/LP variants do not collide.
- `quantity`: Keep as a string. Legacy files mix numeric and non-numeric availability text.
- `details`: Canonical replacement for legacy `More Info`.
- `imageURL`: Prefer `https`.
- `imageURL`: This can initially come from Record Store Day, but the intended long-term source is Apple Music artwork after enrichment.
- `sourceURL`: Original Record Store Day detail page when available.
- `releaseType`: Optional normalized tag if the source distinguishes items such as `exclusive`, `first`, `small-run`, or `regional`.
- `appleMusic`: Optional provider metadata added by a later enrichment pass. This is the preferred source for static artwork and extra artist metadata.
- `spotify`: Optional provider metadata added by a later enrichment pass.

## Legacy Input Mapping

Legacy bundled objects map as follows:

- `Artist` -> `artist`
- `Album` -> `title`
- `Format` -> `format`
- `Label` -> `label`
- `Quantity` -> `quantity`
- `PhotoURL` -> `imageURL`
- `More Info` -> `details`

Generated defaults for legacy imports:

- `schemaVersion = 1`
- `event` supplied by the import command
- `sourceURL = null`
- `releaseType = null`
- `appleMusic = null`
- `spotify = null`

## File Layout

Suggested repository layout:

- `data/releases/rsd-2026.json`
- `data/releases/rsd-black-friday-2026.json`
- `scripts/validate_release_json.py`
- `scripts/enrich_with_apple_music.py`

## Migration Plan

1. Add a typed app model that can decode the canonical schema.
2. Keep a temporary legacy importer so existing bundled files still work.
3. Generate the 2026 file into `data/releases/`.
4. Switch the app to load the canonical file for the selected event.
5. Add a provider-enrichment step for Apple Music and Spotify IDs/URLs.
6. Switch artwork to Apple Music-hosted artwork once enrichment coverage is good enough.

## Validation Rules

Minimum checks before a file is bundled:

- top-level `schemaVersion`, `event`, and `releases` are present
- every release has non-empty `artist`, `title`, `format`, `label`, `details`, and `imageURL`
- every `id` is unique
- every `imageURL` uses `https`
- no duplicate `(artist, title, format)` tuples after normalization

## Apple Music Enrichment

Use Apple Music catalog data to enrich releases without requiring end-user authorization.

Expected inputs:

- Apple Music developer token
- storefront, for example `us`
- canonical release JSON

Expected outputs:

- `appleMusic.albumID`
- `appleMusic.albumURL`
- `appleMusic.artistName`
- `appleMusic.artistURL`
- `appleMusic.artwork.*`

Implementation note:

- This enrichment step should run offline in a script or backend job, not in the shipped client.
- The app can continue to use `imageURL` as the display field while enrichment coverage is incomplete.
- Once the enriched file has good coverage, `imageURL` should be rewritten to the Apple-hosted artwork URL derived from the artwork template.

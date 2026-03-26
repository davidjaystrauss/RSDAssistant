# RSD 2026 Regional Sources

These are the official 2026 Record Store Day list sources currently identified for regions with distinct public release lists.

## Confirmed official list sources

- US / global
  - Source: `https://recordstoreday.com/SpecialReleases`
  - Notes: Main Record Store Day site. This is the baseline global list.

- Canada
  - Source: `https://recordstoredaycanada.ca/record-store-day-2026/index.php`
  - Notes: Official Canada list with Canadian-only titles marked using the maple leaf symbol.

- UK
  - Source: `https://www.recordstoreday.co.uk/rsd-list`
  - Notes: Official UK list with title detail pages.

- Germany / Austria / Switzerland
  - Source: `https://www.recordstoredaygermany.de/exklusive-releases/releases-zum-rsd-2026/`
  - Notes: Official DACH list published on the Germany site.

- Australia
  - Source: `https://recordstoreday.com.au/releases/`
  - Notes: Official Australia list. The site also publishes a downloadable PDF.

- Japan
  - Source: `https://recordstoreday.jp/item2026/`
  - Notes: Official Japan 2026 item index with individual release detail pages.

## Open questions

- Spain
  - The official Spain site is confirmed, but the 2026 public release list endpoint still needs to be identified.

- France
  - No confirmed public 2026 release list source yet.

- Italy
  - No confirmed public 2026 release list source yet.

## Import strategy

Each official region should become its own canonical file:

- `data/releases/rsd-2026-us.json`
- `data/releases/rsd-2026-canada.json`
- `data/releases/rsd-2026-uk.json`
- `data/releases/rsd-2026-germany.json`
- `data/releases/rsd-2026-australia.json`
- `data/releases/rsd-2026-japan.json`

Do not merge regions into one giant file. Normalize each source independently, then enrich each file with Apple Music metadata and artwork.

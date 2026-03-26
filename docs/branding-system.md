# RSD Assistant Branding System

## Recommended Direction

Primary brand direction: `Catalog Card`

Reason:
- reads clearly at app icon size
- feels archival/editorial rather than childish
- ties directly to release planning and collection management
- adapts cleanly by country and event without changing the underlying mark

Secondary exploration:
- `Sleeve Tab`
- `Stamped Monogram`

## Core Brand Name

Use `RSD Assistant` in UI and branded materials.

Avoid:
- `Helper`
- literal storefront illustrations
- note icons
- multi-object logo mashups

## Icon System

### Base Geometry: Catalog Card

Structure:
- square icon field
- inset rectangular card body
- clipped or chamfered top-right corner
- centered circular record-label cue
- one horizontal rule or metadata line

Visual meaning:
- card = catalog / saved release / printed list
- circle = vinyl identity without cartoon grooves
- clipped corner = tactile printed artifact

### Icon Grid

Use a simple construction grid:
- outer field padding: 10%
- card body inset: 14%
- clipped corner depth: 10%
- center circle diameter: 24%
- metadata rule thickness: 3-4%
- metadata rule width: 26-32%

### Rendering Rules

- 2 or 3 colors max
- no tiny text in the icon
- no realistic record grooves
- no drop shadows required for recognition
- shape must read at `60x60`
- use flat or lightly textured fills, not busy gradients

## Variant Directions

### 1. Catalog Card

Use for:
- app icon
- primary splash/header mark
- PDF/export headers

Design notes:
- strong geometry
- editorial spacing
- restrained circular cue

### 2. Sleeve Tab

Use for:
- optional seasonal marketing artwork
- feature banners

Design notes:
- more music-specific
- still abstract
- no literal storefront

### 3. Stamped Monogram

Use for:
- secondary badge
- favicons / small monochrome usages
- optional settings/about mark

Design notes:
- very legible at tiny sizes
- utilitarian
- strongest if reduced to one color

## Typography

Style:
- condensed, editorial, assertive
- all caps or small caps for headers
- avoid playful rounded fonts

Recommended feel:
- poster typography
- record spine typography
- release-sheet typography

Wordmark pattern:
- `RSD` on line one
- `ASSISTANT` on line two or set smaller inline

## Color System

The shape system stays constant.
Color and surface treatment shift by country/event.

### US

- background: `#F7F3EA`
- primary: `#17366C`
- accent: `#B23A3A`
- neutral dark: `#1B1D22`

Use:
- navy card
- muted red center circle or rule
- cream field

### Canada

- background: `#FAF8F7`
- primary: `#C6212A`
- accent: `#20242A`
- neutral: `#F0F0F0`

Use:
- red card
- charcoal circle/rule
- white or soft-white field

### UK

- background: `#F6F4F6`
- primary: `#113B8C`
- accent: `#B51E2E`
- neutral dark: `#1D2230`

Use:
- royal blue card
- red accent
- off-white field

### Germany

- background: `#F5F1E8`
- primary: `#151515`
- accent: `#C62828`
- neutral: `#E7DFC9`

Use:
- black card
- red accent
- warm paper field

### Australia

- background: `#F4F0E6`
- primary: `#0E3E84`
- accent: `#C8A233`
- neutral dark: `#17202A`

Use:
- deep blue card
- gold accent
- sand field

### Black Friday

Dark mode:
- background: `#080808`
- primary: `#151515`
- accent: `#C89B2E`
- secondary accent: `#8A1F1F`

Light mode:
- background: `#F6EBDD`
- primary: `#241A18`
- accent: `#B6422E`
- metallic accent: `#C8A06A`

Use:
- rich black field
- black-on-black card
- warm metallic circle/rule

## App Header System

Use a branded large-title area that borrows from the icon geometry:
- large title text: `RSD Assistant`
- secondary line: active list, e.g. `2026 - Canada`
- small catalog-card motif or circular accent beside the title

Collapsed state:
- suppress repeated large text where redundant
- keep the dedicated list-switcher control

## PDF Branding

PDF headers should feel official and printable:
- use `Record Store Day Favorites`
- use the event/country palette
- include a subtle catalog-card accent, not a novelty icon
- avoid dark text on dark fills
- prefer clean banner blocks and thin accent rules

## Implementation Guidance

### Phase 1

- replace app icon with `Catalog Card`
- update app header styling to `RSD Assistant`
- align PDF banner styling with the same geometry

### Phase 2

- add per-list color tokens for brand accents
- apply the correct palette automatically by list country/event
- create a monochrome alternate for settings/about

### Phase 3

- create optional seasonal variants
- Black Friday gets the most dramatic treatment
- country variants stay color-led, not shape-led

## Final Recommendation

Ship:
- icon: `Catalog Card`
- wordmark: `RSD Assistant`
- themed palettes by country/event

Keep in reserve:
- `Sleeve Tab` for marketing art
- `Stamped Monogram` for tiny monochrome uses

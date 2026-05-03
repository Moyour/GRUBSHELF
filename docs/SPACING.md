# GrubShelf spacing & padding guide

This app uses a **single source of truth**: `GrubShelf/DesignSystem/Spacing.swift` (`AppSpacing`). All new UI should use these tokens—**not raw numbers**—for `padding`, `spacing:` on stacks, and spacing arguments on scroll/grid APIs.

## Rules

1. **No magic numbers** for layout spacing in SwiftUI views. If you need a value that does not exist, add a named constant to `AppSpacing` with a short comment, then use it.
2. **Prefer semantic tokens** (e.g. `listRowCardInsets`, `bannerCornerRadius`) over reusing a generic token at random.
3. **`spacing: 0`** is allowed for stacked chrome (e.g. tab bar, split sections) and `safeAreaInset(..., spacing: 0)` — those are structural, not visual rhythm.
4. **List rows**: use **`AppSpacing.listRowCardInsets`** for card-style rows and **`AppSpacing.listRowSectionControlInsets`** for full-width controls (e.g. segmented `Picker` inside a `List`). Do not hand-roll duplicate `EdgeInsets`.

## Token reference (points)

| Token | Pt | Use |
|--------|-----|-----|
| `microGap` | 2 | Subtitle/meta line spacing; smallest vertical inset; part of list row vertical rhythm |
| `compactGap` | 4 | Tight `VStack`/`HStack`, `LazyVGrid` spacing, chip inner vertical padding, small top offsets |
| `filterChipInnerSpacing` | 5 | Space between parts inside filter capsule chips (reserved — wire when capsule filters ship) |
| `denseSpacing` | 6 | Dense `HStack`/`VStack`; skeleton lines; filter glyph horizontal padding; combined with `microGap` for list rows |
| `smallSpacing` | 8 | Secondary stack spacing; sync banner |
| `mediumSpacing` | 10 | Badges, transfer rows, toast `HStack`, filter capsule outer horizontal padding |
| `rowSpacing` | 12 | Primary row spacing; glass toolbar label **horizontal** padding; segmented control vertical padding (tabs) |
| `screenPadding` | 16 | Screen horizontal margins; list leading/trailing inside `listRow*` insets |
| `cardPadding` | 16 | Padding **inside** card surfaces (same value as `screenPadding`, different meaning) |
| `sectionSpacing` | 24 | Space between major sections (onboarding, sheets) |
| `homeChromeVerticalSpacing` | 16 | Vertical gap between legacy Home header blocks (reserved for section rhythm) |
| `filterChipOuterVerticalPadding` | 7 | Filter capsule outer vertical padding (reserved — see `filterChipInnerSpacing`) |
| `priorityChipVerticalPadding` | 9 | Home priority capsule chips — vertical inset (reserved — wire when that UI uses it) |
| `toastVerticalPadding` | 14 | Toast inner vertical padding |
| `inlineSearchCardVerticalPadding` | 10 | Vertical padding for cards wrapping `InlineSearchFieldRow` |
| `bannerCornerRadius` | 14 | Compact banners / inline strips (e.g. review CTA, quick-action chrome) |
| `floatingAddButtonScrollClearance` | 72 | Bottom spacer when content scrolls under the FAB |
| `scrollVerticalBreathingRoom` | 40 | Minimum `Spacer(minLength:)` for empty states, onboarding, scroll rhythm |
| `scannerOverlayBottomInset` | 40 | Barcode scanner instruction stack inset from safe area |
| `quantityColumnMinWidth` | 24 | Pantry row mono quantity column minimum width |
| `inlineSearchRowMinHeight` | 36 | Inline search bar row height target |
| `minTouchTarget` | 44 | Minimum tap targets |
| `iconSizeSmall` | 36 | Compact icon squares (e.g. some dashboard tiles) |
| `iconSizeMedium` | 40 | Standard toolbar / row icon squares |
| `iconSizeLarge` | 48 | Large icon containers |

### Radii & shadow (in `AppSpacing`)

| Token | Pt / value | Use |
|--------|------------|-----|
| `cardRadius` | 16 | Cards, main surfaces |
| `heroRadius` | 24 | Hero blocks |
| `buttonRadius` | 12 | Buttons, search fields |
| `iconRadius` | 10 | Small squircle icon backgrounds |
| `badgeCornerRadius` | 8 | Status chips, calendar cells, compact pills |
| `shadowOpacity` / `shadowRadius` / `shadowY` | 0.08 / 4 / 2 | Card shadow |

### List insets (computed `EdgeInsets`)

| Name | Values | Use |
|------|--------|-----|
| `listRowCardInsets` | vertical: `denseSpacing + microGap` (8pt); horizontal: `screenPadding` | Card-style rows: Home pantry, Pantry tab, shopping lists, catalog sheets, etc. |
| `listRowSectionControlInsets` | vertical: `rowSpacing`; horizontal: `screenPadding` | Segmented `Picker` (or similar) **inside** a `List` section |

## Common patterns

### Screen edges

- Horizontal padding for page content: **`screenPadding`**.
- Horizontal scroll content insets: **`contentMargins(.horizontal, AppSpacing.screenPadding, ...)`** where used (e.g. dashboard carousel).

### Cards

- Inner padding: **`cardPadding`** (all sides or axis-specific as needed).
- List cards: apply **`listRowCardInsets`** on the row; inner content often also uses **`cardPadding`** on the card body for the “floating card” look.

### Stacks

- Between sections: **`sectionSpacing`**.
- Between normal lines: **`rowSpacing`**.
- Tighter blocks (secondary): **`smallSpacing`**.
- Label + meta column: **`compactGap`** or **`microGap`** depending on density.

### Filter chips (when implemented)

- Inner `HStack` spacing: **`filterChipInnerSpacing`**.
- Glyph padding: **horizontal `denseSpacing`**, **vertical `microGap`**.
- Outer capsule: **horizontal `mediumSpacing`**, **vertical `filterChipOuterVerticalPadding`**.
- Priority row chips: **`priorityChipVerticalPadding`**.

### System tab bar (`TabView`)

- The OS lays out the tab bar and safe areas; **do not** add a custom bottom “clearance” constant for scroll content unless a specific sheet or overlay requires it.
- Tab tint uses brand accent (`.tint(.gsBrandPrimary)` on the tab view).

### Toolbars (`GlassyToolbarLabelButton`)

- Label button padding: **horizontal `rowSpacing`**, **vertical `smallSpacing`**.

### Toasts

- Inner vertical: **`toastVerticalPadding`**.
- Icon row spacing: **`mediumSpacing`**.
- Secondary top inset where needed: **`smallSpacing`**.

### Segmented controls (outside `List`)

- **Horizontal** `screenPadding`, **vertical** `rowSpacing` (Home/Expense tab chrome, Pantry tab filter) so they align with in-list segmented rows.

## Changing the system

When adjusting the scale, update **`Spacing.swift`** first, then this doc if names or values change. Scan for literals:

```bash
rg 'spacing: [0-9]' GrubShelf --glob '*.swift'
rg '\.padding\(\.[a-z]+, [0-9]+\)' GrubShelf --glob '*.swift'
```

After changes, verify lists and sheets still clear the **system** tab bar and any FABs (`floatingAddButtonScrollClearance` where used).

### `Spacer(minLength:)`

Prefer **`AppSpacing.smallSpacing`** (8), **`AppSpacing.sectionSpacing`** (24), and **`AppSpacing.scrollVerticalBreathingRoom`** (40) instead of raw values.

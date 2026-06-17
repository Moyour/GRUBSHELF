# GrubShelf — Complete Color Audit (Rebrand Reference)

Every color used in the app, with exact locations and roles.

---

## 1. Design System Colors (Colors.swift)

| Constant | Source | Hex | Light/Dark |
|----------|--------|-----|------------|
| `primaryGreen` | PrimaryGreen asset | #1F7A4C | Same both |
| `appBackground` | Background asset | #F1F2F4 / #111111 | Light gray / Near black |
| `cardBackground` | CardBackground asset | #FFFFFF / #252527 | White / Dark gray |
| `primaryText` | PrimaryText asset | #1C1C1E / #FFFFFF | Near black / White |
| `secondaryText` | SecondaryText asset | #6E6E73 / #A1A1A6 | Mid gray / Light gray |
| `errorRed` | ErrorRed asset | #D64545 | Same both |
| `warningAmber` | WarningAmber asset | #F4A260 | Same both |
| `successGreen` | SuccessGreen asset | #2A9D8F | Same both (teal) |
| `divider` | Divider asset | #E5E5EA | Same both |
| `accentBlue` | `Color.blue` (system) | System blue | Unused |
| `pantryTeal` | Hardcoded RGB | #2A9D8F | Same as successGreen |
| `shoppingBlue` | Hardcoded RGB | #5B7FFF | Same both |
| `insightsPurple` | Hardcoded RGB | #8B5CF6 | Same both |

**AccentColor** (Assets): #1F7A4C — used by system controls (e.g. `.buttonStyle(.borderedProminent)`), same as primaryGreen.

---

## 2. System & Ad-Hoc Colors

| Color | Usage |
|-------|-------|
| `.white` | Icons on colored backgrounds; barcode scanner overlay; SyncBanner text; calendar selected day |
| `.black` | WelcomeView Sign in with Apple button text (on white bg); BarcodeScannerView full-screen background |
| `Color.gray.opacity(0.15)` | Skeleton loading placeholders (SkeletonView) |
| `Color.gray.opacity(0.3)` | EmailAuthView password strength bar (weak segments) |
| `Color.clear` | Spacer frames; calendar empty day dot; CreateShoppingListSheet listRowBackground |
| `.regularMaterial` | ProfileView settings button; glass toolbar buttons |
| `.ultraThinMaterial` | ToastView background |
| `UIColor.black` | BarcodeScannerView `view.backgroundColor` |
| `UIColor.white` | BarcodeScannerView labels, border (`cgColor`) |

---

## 3. Shadow & Effects

| Location | Color |
|----------|-------|
| `DesignSystem/Shadow.swift` – cardShadow | `.black.opacity(0.08)` |
| `DesignSystem/Shadow.swift` – pillShadow | `.black.opacity(0.06)` |

| `ToastView` | `.black.opacity(0.12)` |

---

## 4. Color Usage by File (Every Occurrence)

### GrubShelfApp.swift
- `Color.appBackground` — Loading/splash background

### ContentView.swift
- Opacity only (no colors)

### GrubShelf/DesignSystem/Colors.swift
- All color definitions

### GrubShelf/DesignSystem/Shadow.swift
- `.black.opacity(AppSpacing.shadowOpacity)` (0.08) — card shadow
- `.black.opacity(0.06)` — pill shadow
- `Color.cardBackground` — dashboardCardSurface
- `Color.appBackground` — (indirect via views)

---

### Auth & Onboarding

**WelcomeView.swift**
- `Color.primaryGreen` — Logo/icon
- `Color.primaryText` — Headline
- `Color.secondaryText` — Subtext
- `Color.white` — Sign in with Google button background
- `Color.black` (`.black`) — Sign in with Google button text
- `Color.divider` — Input borders (stroke)
- `Color.cardBackground` — Auth form card
- `Color.errorRed` — Validation error text
- `Color.appBackground` — Screen background

**EmailAuthView.swift**
- `Color.secondaryText` — Eye toggle, unmet requirements labels
- `Color.gray.opacity(0.3)` — Weak password strength segments
- `passwordStrengthColor` — Weak/Medium → `secondaryText`, Strong → `primaryGreen`
- `Color.errorRed` — Auth error message

**FeatureOnboardingView.swift**
- `Color.appBackground` — Screen background
- `Color.secondaryText` — Skip button
- `Color.primaryText` — Headlines
- `Color.secondaryText` — Subtext
- `Color.primaryGreen` — Tint for Next/Get Started button

**CreateHouseholdView.swift**
- `Color.appBackground` — Background
- `Color.primaryGreen` — Invite icon
- `Color.primaryText` — Headlines, household names
- `Color.secondaryText` — Subtext
- `Color.cardBackground` — Invite cards
- `Color.divider` — Divider line
- `Color.primaryGreen` — Tint for Join button

**AddFirstItemView.swift**
- `Color.primaryGreen` — Icon
- `Color.primaryText` — Title
- `Color.secondaryText` — Subtext
- `Color.cardBackground` — Card
- `Color.divider` — Border stroke
- `Color.primaryGreen` — Tint for buttons
- `Color.appBackground` — Background

---

### Dashboard

**DashboardView.swift** (Rich layout)
- `Color.appBackground` — Background
- `Color.warningAmber` — AccentCard Expiring (when count > 0)
- `Color.secondaryText` — AccentCard inactive state
- `Color.warningAmber` — AccentCard Low Stock (when count > 0)
- `Color.shoppingBlue` — AccentCard To Buy (when count > 0)
- `Color.successGreen` / `Color.errorRed` — Waste indicator
- `Color.primaryGreen` — Health ring, legend, streak, quick actions
- `Color.insightsPurple` — Budget ring, legend
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.pantryTeal` — Pantry snapshot card
- `Color.shoppingBlue` — Shopping snapshot card
- `Color.warningAmber` — Needs review banner, expiry cards
- `Color.insightsPurple` — Budget card (on track)
- `Color.errorRed` — Budget card (over)
- `Color.primaryGreen` — Activity card, Needs Review CTA

*(DashboardGlassLayout.swift removed — was an unused layout experiment)*
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.errorRed` — Waste total, activity
- `Color.successGreen` — Zero waste text
- `Color.insightsPurple` / `Color.warningAmber` / `Color.errorRed` — Budget card states

---

### Pantry

**PantryView.swift**
- `Color.appBackground` — Background
- `Color.pantryTeal.opacity(0.5)` — Empty state icon
- `Color.primaryText` / `Color.secondaryText` — Empty state, category pills
- `Color.pantryTeal` — Category pill active fill
- `Color.white` — FAB icon (on primaryGreen bg)
- `Color.secondaryText.opacity(0.5)` — Chevron
- `Color.pantryTeal` — Tint for segmented picker
- `Color.secondaryText` — Item count

**PantryItemRow.swift**
- `stateAccentColor` — Category icon, icon bg: `pantryTeal` (default), `errorRed` (expired), `warningAmber` (expiring/low/stale)
- `Color.primaryText` — Item name
- `Color.warningAmber` — Low stock quantity label
- `Color.secondaryText` — Quantity, category badge, expiry (default)
- `expiryColor` — `errorRed` (expired), `warningAmber` (expiring), else `secondaryText`
- `Color.pantryTeal` — Increment (+) button
- `badge.color` — Status badges: `errorRed`, `warningAmber`
- `Color.appBackground` — Category tag bg

**ExpiryCalendarView.swift**
- `Color.primaryText` — Month title, day labels, section header
- `Color.secondaryText` — Weekday headers, empty state
- `Color.appBackground` — Background
- `.white` — Selected day text
- `Color.primaryGreen` — Today (non-selected) text, dot for items
- `Color.primaryText` — Default day text
- `Color.primaryGreen` — Selected day bg
- `Color.primaryGreen.opacity(0.1)` — Today bg (when not selected)
- `Color.secondaryText` — Expired-item dot
- `Color.clear` — Empty day dot

**AddItemHubSheet.swift**
- `Color.primaryText` / `Color.secondaryText` — Section titles, catalog rows, action cards, loading
- `Color.primaryGreen` — Recent item icon, catalog plus, action card icon
- `Color.cardBackground` — Card surfaces
- `Color.errorRed` — Search error
- `Color.white` — "Choose Photo" button text
- `Color.primaryGreen` — "Choose Photo" button bg

**AddEditPantryItemView.swift**
- `Color.errorRed` — Validation, error section

**PantryReviewView.swift**
- `Color.appBackground` — Background
- `Color.primaryGreen` — Icon, CTA
- `Color.primaryText` / `Color.secondaryText` — Labels

**BarcodeScannerView.swift (UIKit)**
- `UIColor.black` — View background
- `UIColor.white` — Instruction label, permission label, scan frame border
- `UIColor.white.cgColor` — Frame border

---

### Shopping

**ShoppingListsView.swift**
- `Color.appBackground` — Background
- `Color.shoppingBlue.opacity(0.5)` — Empty state icon
- `Color.primaryText` / `Color.secondaryText` — Empty state
- `Color.white` — CTA button text

**ShoppingListCard.swift**
- `Color.successGreen` — Complete icon, Ready/All done badges
- `Color.shoppingBlue` — Incomplete icon, progress bar, "to go"
- `Color.primaryText` / `Color.secondaryText` — Labels

**ShoppingListDetailView.swift**
- `Color.successGreen` — Header, add icon (when empty)
- `Color.shoppingBlue` — Add-item affordances
- `Color.warningAmber` — Expiry badge
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.appBackground` — Background

**ShoppingItemRow.swift**
- `Color.successGreen` — Completed checkmark
- `Color.secondaryText` — Incomplete checkmark, quantity
- `Color.primaryText` — Item name (incomplete)

**CreateShoppingListSheet.swift**
- `Color.clear` — listRowBackground
- `Color.appBackground` — Background

**CatalogSearchSheet.swift**
- `Color.primaryGreen` — Search icon, catalog result accent
- `Color.primaryText` / `Color.secondaryText` — Result labels
- `Color.errorRed` — Search error
- `Color.appBackground` — Background

**TransferConfirmationView.swift**
- `Color.primaryGreen` — Icon, CTA, transfer card accent
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.errorRed` — Error, over-budget
- `Color.cardBackground` — Card
- `Color.primaryGreen.opacity(0.15)` — Card tint
- `Color.primaryGreen.opacity(0.3)` — Card stroke
- `Color.appBackground` — Background

---

### Insights

**InsightsView.swift**
- `Color.appBackground` — Background
- `Color.primaryGreen.opacity(0.4)` — Dimmed hero
- `Color.primaryText` / `Color.secondaryText` — Labels
- `.white` — Log Purchase button text
- `Color.primaryGreen` — Log Purchase bg, charts, values, tips, unlocks
- `heroColor` — primaryGreen / secondaryText / secondaryText (by budget state)
- `Color.primaryGreen.gradient` — Chart fill
- `Color.primaryGreen.opacity(0.1)` — Budget CTA bg
- `Color.primaryGreen.opacity(0.12)` — Tip badge
- `Color.secondaryText.opacity(0.12)` — Secondary tip badge
- `Color.cardBackground` — Locked overlay
- `tipColor()` — success→primaryGreen, warning→secondaryText, info→primaryGreen
- `Color.primaryGreen.opacity(0.15)` / `Color.cardBackground` — Unlock fill

**LogPurchaseSheet.swift**
- `Color.primaryGreen` — Icon

**CustomizeAnalyticsSheet.swift**
- `Color.primaryGreen` — Toggle icon
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.appBackground` — Background

**ReceiptScanSheet.swift**
- `Color.secondaryText` — Hint
- `Color.primaryGreen.opacity(0.6)` — Dimmed hint
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.primaryGreen` — Capture button bg
- `.white` — Capture button text
- `Color.errorRed` — Error
- `Color.appBackground` — Background

**ReceiptConfirmationSheet.swift**
- `Color.secondaryText` — Item prices
- `Color.errorRed` — Error message

---

### Profile

**ProfileView.swift**
- `Color.primaryGreen.opacity(0.15)` — Avatar circle fill
- `Color.primaryGreen` — Avatar initial, Edit, Settings icon
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.secondaryText.opacity(0.6)` — Hint
- `Color.clear` — Tab bar clearance
- `.regularMaterial` — Settings button
- `Color.secondaryText` — Section footer

**FamilyMembersView.swift**
- `Color.primaryText` / `Color.secondaryText` — Member rows
- `Color.primaryGreen` — Admin badge

**InviteMemberSheet.swift**
- `Color.primaryGreen` — Icon, CTA
- `Color.primaryText` / `Color.secondaryText` — Labels
- `Color.errorRed` — Validation

---

### Shared Components

**FloatingAddButton.swift**
- `Color.primaryGreen` — FAB background
- `.white` — FAB icon
- `Color.primaryGreen` — GlassyToolbarIconButton icon
- `Color.primaryGreen` — GlassyToolbarLabelButton text/icon
- `Color.primaryGreen` — NavigationBarAddButton (via GlassyToolbarIconButton)

**TabView (main shell, `ContentView`)**
- `gsBrandPrimary` / accent — Selected tab (via `.tint(.gsBrandPrimary)`)

**SyncBanner.swift**
- `Color.primaryGreen` — Banner background
- `.white` — Text (2×)

**ToastView.swift**
- `tintColor` — success/info → primaryGreen, error/warning → secondaryText
- `Color.primaryText` — Message text
- `Color.secondaryText` — Dismiss button
- `.black.opacity(0.12)` — Shadow

**ValidationErrorText.swift**
- `Color.errorRed` — Error text

**InlineSearchFieldRow.swift**
- `Color.secondaryText` — Magnifying glass, clear button

**SkeletonView.swift**
- `Color.white.opacity(0.3)` — Shimmer overlay
- `Color.gray.opacity(0.15)` — Skeleton line/circle/rect fills

---

### Settings & Legal

**SettingsView.swift**
- (Uses system Form; no explicit colors)

**FAQView.swift**
- `Color.appBackground` — Background
- `Color.primaryText` / `Color.secondaryText` — Content
- `Color.cardBackground` — Section bg

**TermsView.swift**
- `Color.primaryText` / `Color.secondaryText` — Content
- `Color.appBackground` — Background

**PrivacyView.swift**
- `Color.primaryText` / `Color.secondaryText` — Content
- `Color.appBackground` — Background

**AboutView.swift**
- `Color.primaryGreen` — Leaf icon, email link
- `Color.primaryText` — App name
- `Color.secondaryText` — Tagline, version, description
- `Color.appBackground` — Background

---

## 5. Opacity Variants Used

| Base | Opacity | Context |
|------|---------|---------|
| primaryGreen | 0.06, 0.08, 0.1, 0.12, 0.15, 0.2, 0.3, 0.4 | Card tints, icon circles, strokes |
| successGreen | 0.12 | Badge bg |
| shoppingBlue | 0.5, 0.12, 0.15 | Empty state, icon bg, card tints |
| pantryTeal | 0.5, 0.08, 0.12, 0.15 | Empty state, card tints |
| insightsPurple | 0.12 | Card tints |
| warningAmber | 0.08, 0.15, 0.6 | Banner bg, icon fill |
| errorRed | — | Solid only |
| secondaryText | 0.4, 0.5, 0.6, 0.12 | Dimmed labels, badge |
| white | 0.18, 0.3 | Stroke, shimmer |
| black | 0.06, 0.08, 0.12 | Shadows |
| gray | 0.15, 0.3 | Skeleton, password bar |

---

## 6. Semantic Roles (Rebrand Mapping)

| Role | Current Color(s) | Files to Update |
|------|------------------|-----------------|
| Brand / primary CTA | primaryGreen | All |
| Success / completed | successGreen | Shopping, Dashboard, PantryItemRow |
| Caution | warningAmber | Dashboard, PantryItemRow, Transfer |
| Error / negative | errorRed | Validation, budget over, waste |
| Section: Pantry | pantryTeal | PantryView, Dashboard, PantryItemRow |
| Section: Shopping | shoppingBlue | Shopping views, Dashboard |
| Section: Budget | insightsPurple | Dashboard, Insights |
| Headlines | primaryText | Everywhere |
| Supporting text | secondaryText | Everywhere |
| Surfaces | appBackground, cardBackground | Everywhere |
| Borders | divider | Welcome, AddFirstItem, CreateHousehold |
| Loading skeleton | gray 0.15 | SkeletonView |
| Shadows | black 0.06–0.12 | Shadow, Glass, Toast |

---

## 7. Rebrand Checklist

1. **Assets** — PrimaryGreen, SuccessGreen, WarningAmber, ErrorRed, PrimaryText, SecondaryText, Background, CardBackground, Divider, AccentColor
2. **Colors.swift** — pantryTeal, shoppingBlue, insightsPurple (RGB)
3. **System colors** — `.white`, `.black`; decide if barcode scanner stays black
4. **Gray** — SkeletonView, EmailAuthView password bar
5. **Shadows** — Shadow.swift, ToastView
6. **Materials** — Keep or adjust .ultraThinMaterial, .regularMaterial
7. **ToastView** — success uses primaryGreen; error/warning use secondaryText (consider errorRed for error)
8. **AccentColor** — Match new primary

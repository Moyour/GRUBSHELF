# GrubShelf

**Reduce waste. Save money. Simplify meals.**

GrubShelf is an iOS app that helps households manage their pantry inventory, plan shopping trips, track spending, and reduce food waste through smart alerts and insights.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Screens & Functionality](#screens--functionality)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Testing](#testing)

---

## Features

### Authentication & Onboarding

- **Sign in with Google** — One-tap Google authentication
- **Sign in with Apple** — Native Apple ID sign-in
- **Email authentication** — Sign up and sign in with email/password
- **Feature onboarding** — First-time user walkthrough
- **Household creation** — Create or join a household
- **Add first item** — Guided flow to add the first pantry or shopping item

### Dashboard

- **Health score** — Pantry health indicator (0–100) with contextual subtitle
- **Streak tracking** — Consecutive days of pantry engagement
- **Quick actions** — Add Item, Shopping, Log Purchase
- **Stats cards** — Expiring count, Low Stock count, To Buy count
- **Expiry alert** — Items expiring within 3 days with calendar view
- **Pantry snapshot** — Total items, categories, low stock indicator
- **Shopping progress** — Pending items, completion percentage, Continue Shopping
- **Budget snapshot** — Monthly spend estimate, savings, trend
- **Needs review** — Stale items prompting usage review
- **Activity metrics** — Recent activity summary

### Pantry

- **Filter views** — All, Expiring, Low Stock, Categories
- **Search** — Search items by name
- **Add items** — Via Add Item Hub:
  - **Scan barcode** — Open Food Facts lookup
  - **Search catalog** — Grocery catalog search
  - **Add manually** — Full form (name, quantity, unit, expiry, category)
  - **Quick add recent** — Recently added items
- **Item states** — Active, Low Stock, Expiring Soon, Expired, Stale, Archived
- **Swipe actions** — Edit, Delete
- **Removal flow** — Used it / Wasted (with optional cost for waste events)
- **Auto-archive** — Configurable grace period for expired items
- **Pantry review** — Review stale items (usage reminders)

### Shopping Lists

- **Multiple lists** — Create and manage multiple shopping lists
- **Add items** — Inline search & add with grocery catalog suggestions
- **Duplicate warning** — Warns when adding items already in pantry above threshold
- **Checkbox completion** — Mark items done; completed move to bottom
- **Complete All** — Mark all pending items complete
- **Transfer to Pantry** — Move completed items to pantry with:
  - Editable quantities
  - Optional expiry dates
  - Trip cost entry (for budget tracking)
  - Transaction records
- **Catalog search sheet** — Full catalog search when adding items
- **Done button** — Dismiss keyboard on add-item screen

### Insights

- **Budget tab**
  - Set monthly or weekly budget
  - Currency selection (USD, EUR, GBP, NGN, etc.)
  - Progress bar (spent vs remaining)
  - Unlogged trips banner — Prompt to add cost for past transfers
  - Waste callout — Estimated waste impact
  - Log Purchase — Manual purchase logging (amount, date, store)
- **Analytics tab**
  - Customizable analytics cards
  - Spending trends
  - Savings from avoided duplicates
  - Activity metrics

### Profile

- **Account** — Name, email, household, edit profile
- **Family members** — View members, roles (admin/member), remove members
- **Invite members** — Send household invites
- **Pending invites** — Accept/decline invites
- **Sign out**
- **Delete account**
- **Export data** — Export pantry and shopping data

### Settings

- **Appearance** — System, Light, Dark theme
- **Pantry** — Auto-archive expired items, grace period (1–30 days)
- **Notifications** — Expiry alerts, Low stock alerts, Usage review reminders
- **Help** — FAQ, About, Terms & Conditions, Privacy Policy

### Notifications

- **Expiry alerts** — Items expiring within 3 days
- **Low stock alerts** — Items at or below threshold
- **Usage reminders** — Items not updated in expected cycle (category-based)

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Platform** | iOS (SwiftUI) |
| **Backend** | Supabase (PostgreSQL, Auth, Realtime) |
| **Auth** | Supabase Auth, Sign in with Apple, Google Sign-In |
| **Charts** | Swift Charts |
| **Packages** | supabase-swift, GoogleSignIn-iOS |

---

## Project Structure

```
GrubShelf/
├── GrubShelf/
│   ├── GrubShelfApp.swift          # App entry, auth flow, onboarding
│   ├── ContentView.swift         # Tab navigation, view model wiring
│   ├── Models/                   # PantryItem, ShoppingItem, Transaction, etc.
│   ├── ViewModels/               # Dashboard, Pantry, Shopping, Insights, etc.
│   ├── Views/
│   │   ├── Auth/                 # WelcomeView, EmailAuthView
│   │   ├── Dashboard/            # DashboardView
│   │   ├── Pantry/               # PantryView, AddItemHubSheet, BarcodeScanner
│   │   ├── Shopping/             # ShoppingListsView, ShoppingListDetailView
│   │   ├── Insights/             # InsightsView, BudgetSettingsSheet
│   │   ├── Profile/              # ProfileView, FamilyMembersView
│   │   ├── Settings/             # SettingsView, FAQView
│   │   ├── Onboarding/           # FeatureOnboarding, CreateHousehold, AddFirstItem
│   │   └── Components/           # ToastView, FloatingAddButton, SyncBanner
│   ├── Services/                 # Auth, SupabaseManager, NotificationService
│   ├── Repositories/             # Supabase*Repository implementations
│   ├── Extensions/               # CurrencyFormatter, etc.
│   └── DesignSystem/             # Colors, Typography, Spacing, Shadow
├── GrubShelfTests/               # Unit tests
├── supabase/                     # Migrations, config
└── docs/                         # GOOGLE_SIGNIN_SETUP, APPLE_SIGNIN_SETUP
```

---

## Screens & Functionality

### Main Tabs

1. **Dashboard** — Overview, quick actions, stats
2. **Pantry** — Inventory management
3. **Shop** — Shopping lists
4. **Insights** — Budget & analytics
5. **Profile** — Account & household

### Key Flows

| Flow | Description |
|------|-------------|
| Add to Pantry | Add Item Hub → Scan / Search / Manual → Save |
| Add to Shopping | List detail → Search & add → Catalog suggestions or manual |
| Transfer to Pantry | Complete items → Transfer → Enter trip cost → Confirm quantities & expiry |
| Log Purchase | Insights or Dashboard → Log Purchase → Amount, date, store |
| Waste tracking | Remove item → "Wasted" → Optional cost → Waste event recorded |

### Data Models

- **PantryItem** — name, quantity, unit, category, expiry, lowStockThreshold, costPerUnitMinor, state (active/lowStock/expiringSoon/expired/stale/archived)
- **ShoppingItem** — name, quantity, unit, category, completed, transferred
- **ShoppingList** — name, transferred
- **Transaction** — Links transfers to pantry with cost
- **WasteEvent** — Tracks wasted items and cost
- **FinanceSettings** — Budget amount, period, currency

---

## Getting Started

### Requirements

- Xcode 15+
- iOS 17+
- Supabase project (or local Supabase via `supabase start`)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd GrubShelf
   ```

2. **Configure Supabase**
   - Create a project at [supabase.com](https://supabase.com) or run locally
   - Add `Config.plist` with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
   - Run migrations: `supabase db push` (or apply `supabase/migrations/*.sql`)

3. **Household invite emails (optional)**
   - Create a [Resend](https://resend.com) API key
   - Deploy the Edge Function: `supabase functions deploy send-household-invite`
   - Set secrets on the hosted project:
     - `RESEND_API_KEY` — required for real delivery
     - `HOUSEHOLD_INVITE_EMAIL_FROM` — e.g. `GrubShelf <notifications@yourdomain.com>` (use a domain you verify in Resend; the default `onboarding@resend.dev` only works for Resend’s own testing limits)
   - Without these secrets, invites still save in the database; the app logs a non-fatal error if the function returns 503

4. **Configure Auth (optional)**
   - See `docs/GOOGLE_SIGNIN_SETUP.md` for Google Sign-In
   - See `docs/APPLE_SIGNIN_SETUP.md` for Sign in with Apple
   - Add `GOOGLE_CLIENT_ID` to `Config.plist` for Google

5. **Build and run**
   - Open `GrubShelf.xcodeproj` in Xcode
   - Select a simulator or device
   - Build and run (⌘R)

---

## Configuration

### Config.plist

| Key | Description |
|-----|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous key |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID (iOS) for Sign in with Google |

### UserDefaults / AppStorage

- `hasCompletedOnboarding` — First-item flow completed
- `hasSeenFeatureOnboarding` — Feature walkthrough seen
- `appearance` — Theme: system, light, dark
- `autoArchiveExpired` — Auto-archive expired items
- `autoArchiveGraceDays` — Days before archiving
- `expiryReminders`, `lowStockReminders`, `usageReminders` — Notification toggles

---

## Testing

Unit tests are in `GrubShelfTests/`:

- `PantryItemTests` — State transitions, validation
- `PantryViewModelTests`
- `ShoppingListViewModelTests`
- `ShoppingListsViewModelTests`
- `DashboardViewModelTests`
- `GroceryCatalogSearchViewModelTests`
- `CurrencyFormatterTests`
- `FinancialServiceTests`
- `ErrorHandlerTests`
- `AppErrorTests`
- `PermissionServiceTests`

Run tests in Xcode: **Product → Test** (⌘U)

---

## Design System

- **Colors** — `Color.primaryGreen`, `Color.successGreen`, `Color.warningAmber`, `Color.errorRed`, etc.
- **Typography** — `AppFont.largeTitle`, `AppFont.sectionTitle`, `AppFont.body`, `AppFont.caption`, `AppFont.button`
- **Spacing** — `AppSpacing.screenPadding`, `AppSpacing.cardPadding`, `AppSpacing.rowSpacing`, `AppSpacing.minTouchTarget`
- **Shadows** — `.cardShadow()` modifier

---

## License

Proprietary. All rights reserved.

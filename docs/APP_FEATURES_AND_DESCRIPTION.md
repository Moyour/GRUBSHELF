# GrubShelf — Complete App Description & Feature Reference

**Last updated:** 2026-06-10  
**Audience:** Product, marketing, testers, investors, and developers  
**Platform:** Native iOS (SwiftUI), Supabase backend

---

## Table of contents

1. [What GrubShelf is](#1-what-grubshelf-is)
2. [Value proposition](#2-value-proposition)
3. [Who it is for](#3-who-it-is-for)
4. [How the app works (core loop)](#4-how-the-app-works-core-loop)
5. [App structure & navigation](#5-app-structure--navigation)
6. [Authentication & account](#6-authentication--account)
7. [Onboarding & first-run experience](#7-onboarding--first-run-experience)
8. [Household & collaboration](#8-household--collaboration)
9. [Roles & permissions](#9-roles--permissions)
10. [Home tab](#10-home-tab)
11. [Pantry tab](#11-pantry-tab)
12. [Shop tab (shopping lists)](#12-shop-tab-shopping-lists)
13. [Expense tab (budget & insights)](#13-expense-tab-budget--insights)
14. [Profile & settings](#14-profile--settings)
15. [Notifications](#15-notifications)
16. [Home Screen widget](#16-home-screen-widget)
17. [Premium subscription](#17-premium-subscription)
18. [Integrations & data sources](#18-integrations--data-sources)
19. [Privacy, export & account control](#19-privacy-export--account-control)
20. [Technical platform notes](#20-technical-platform-notes)
21. [Planned / design-only features](#21-planned--design-only-features)
22. [Related documentation](#22-related-documentation)

---

## 1. What GrubShelf is

**GrubShelf** is a household food hub for iPhone. It connects three things that are usually separate apps or mental notes:

- **Pantry inventory** — what you already have at home  
- **Shared shopping lists** — what you need to buy  
- **Grocery spending** — what you spend and whether you stay on budget  

The app is built for **households** (families, couples, roommates) who want to waste less food, avoid duplicate purchases, and spend more intentionally on groceries.

**Tagline:** *Stop buying what you already have.*

**Subtitle (App Store):** Pantry & grocery list for home

---

## 2. Value proposition

| Problem | How GrubShelf helps |
|--------|---------------------|
| Buying duplicates | Warns when a shopping-list item is already in the pantry (with quantity and recency) |
| Food going bad unnoticed | Expiry tracking, calendar view, and alerts before items expire |
| Lists and pantry out of sync | **Transfer to pantry** moves checked-off shopping items into inventory in one flow |
| Household coordination | Shared lists and pantry; real-time sync via Supabase |
| Unclear grocery spending | Weekly/monthly budget, trip logging, analytics on the Expense tab |
| Setup feels like homework | Start with a shopping list; pantry builds from transfers over time |

**Differentiator:** GrubShelf is one of the few apps that closes the full loop — **shelf → list → store → budget** — with household roles and approval workflows, not just a standalone list app.

---

## 3. Who it is for

- Households that shop together or share a kitchen  
- People who want less food waste and clearer spending  
- Users tired of Notes-app lists and “did we already have milk?” moments  
- **Not yet:** Android users (iOS only today)

---

## 4. How the app works (core loop)

```text
Plan (shopping list at home)
    → Shop (check items off on shared list)
    → Transfer (move completed items to pantry + optional trip cost)
    → Track (expiry, low stock, budget, waste)
    → Repeat
```

**Recommended mental model for new users:** Start with a shopping list, not by scanning every item in the kitchen. After 2–3 trips, the pantry fills itself through transfers.

---

## 5. App structure & navigation

After sign-in and household setup, the main app uses **four bottom tabs**:

| Tab | Purpose |
|-----|---------|
| **Home** | Today’s feed, household activity, shortcuts, budget snapshot, pending approvals (admins) |
| **Pantry** | Full inventory: search, filters, add/edit/remove items |
| **Shop** | Shopping lists: add items, check off, transfer to pantry |
| **Expense** | Budget progress, analytics cards, log purchases |

**Sheets & overlays (global):**

- **Profile** — account, family, settings entry, export, sign out  
- **Add Item Hub** — add to pantry (search, photo, manual)  
- **Log purchase** — receipt scan or manual amount  
- **Pending approvals** — admin review queue  
- **Paywall** — premium upgrade when limits hit  

---

## 6. Authentication & account

### Sign-in methods

| Method | What happens |
|--------|----------------|
| **Sign in with Apple** | OAuth via Supabase; name from Apple on first sign-in only |
| **Continue with Google** | Native Google Sign-In SDK + Supabase token exchange |
| **Continue with email** | Email + password sign-up or sign-in |

### Email-specific flows

- **Sign-up:** Name, email, password; password strength indicator  
- **Email verification:** 6-digit OTP if confirmations enabled  
- **Forgot password:** Email → 6-digit reset code → new password screen  
- **Password reset completion:** Dedicated screen before full app access  

### Session & security

- Session restored on launch (`checkSession`)  
- Rate limiting on sign-in attempts  
- TLS pinning for sensitive external calls (e.g. Open Food Facts)  
- Account deletion via RPC (`delete_user_data`) — removes household data per server rules  

### Name gate (conditional)

After OAuth, if the stored name is empty, `"User"`, or looks like an email, the app shows **“What should we call you?”** (single name field) before household creation. Email sign-up usually skips this if a valid name was entered at registration.

---

## 7. Onboarding & first-run experience

Order for a **brand-new user** (no existing household):

1. **Feature onboarding** — Story-driven walkthrough (5 chapters: kitchen → list → shop → pantry builds → rhythm). Skip or complete.  
2. **Premium intro** — Overview of free vs premium; can continue without subscribing.  
3. **Welcome / sign-in** — Apple, Google, or email.  
4. **Checking invitations…** — Brief load while pending email invites are fetched.  
5. **Name gate** — Only if profile name is invalid (see above).  
6. **Create household** — Enter household name **or** accept a pending invite from the same screen.  
7. **Post-onboarding setup** — Optional one-time screen for household managers: create shopping list, set budget, invite member.  
8. **Main app** (`ContentView`).

**Returning users** with an existing household skip feature tour and premium intro automatically.

**Deep link invites:** `grubshelf://invite?token=<uuid>` opens the app and accepts or prompts sign-in first. See [DEEP_LINKING.md](./DEEP_LINKING.md).

---

## 8. Household & collaboration

### Household creation

- One **household name** per group (e.g. “Smith Family”, “Flat 4B”)  
- Creator becomes **owner** (admin + `is_owner`)  
- All pantry, lists, and budget data scoped to `household_id`  

### Invitations

- **Email invite** — Admin/owner sends invite; edge function sends email with deep link  
- **In-app pending invite prompt** — Sheet when invite matches signed-in email  
- **Accept invite view** — For deep links before or after auth  
- **Create household screen** — Also lists pending invites with “Join” actions  
- Members can invite others (rate-limited on server)  

### Real-time sync

- Pantry and shopping data sync via Supabase (fetch + realtime where enabled)  
- Pull-to-refresh on Home, Pantry, Shop, Expense  
- Offline banner when network unavailable; refresh on reconnect  
- Shopping list widget syncs snapshot to App Group for Home Screen widget  

### Approval workflow

Non-admin **members** add pantry and shopping items as **pending** until an admin approves:

- Pending items visible to submitter; admins see approval queue  
- **Pending Approvals** sheet: approve, reject (with optional reason), bulk approve  
- Push/local notifications for approval requests (category `APPROVAL_REQUEST`)  
- Admins add items as **approved** immediately  

---

## 9. Roles & permissions

| Role | Summary |
|------|---------|
| **Owner** | One per household; delete household, transfer ownership, change all roles |
| **Admin** | Approve items, manage members (not other admins), full pantry/shopping write |
| **Member** | Add pending items; edit own pending; view approved data |
| **Guest** | Read-only on approved pantry and shopping |

**Client-side permission actions** (`PermissionService`):

- Add / edit items (not guest)  
- Delete items, approve items (admin/owner)  
- Manage members, create/delete shopping lists (admin/owner)  
- Modify budget (admin/owner with budget flag)  
- Delete household, change roles (owner only)  

Full matrix: [PERMISSIONS.md](./PERMISSIONS.md), [ROLES.md](./ROLES.md).

---

## 10. Home tab

**Screen:** `HomeRootView` — “The Feed”

### What it shows

- **Greeting + household name + today’s date**  
- **Home dashboard chrome** — Budget bar, shopping progress, expiring/low-stock cues, quick actions  
- **Today’s actions queue** — Up to 5 prioritized slots: expiring → low stock → shopping → budget → stale review (`TodayQueuePlanner`)  
- **Household activity feed** — Recent pantry additions, shopping activity, contextual subtitles  
- **Pending approvals card** — For admins when count > 0  
- **Cold start guide** — Shown when pantry has fewer than 2 items; nudges user to start with shopping list  

### Actions from Home

- Open **Profile**  
- **Add item** (pantry hub sheet)  
- **Log a spend** (receipt / manual flow)  
- Navigate to **Pantry** (with optional focus: expiring, low stock)  
- Navigate to **Shop** or **Expense**  
- Open **expiry calendar** sheet  
- Open **pantry review** for stale items  
- **Review pending approvals** (admins)  
- Pull to refresh all home data sources  

### Dashboard metrics (powering Home)

- Pantry health score (0–100) from expiry, low stock, shopping completion  
- Expiring soon count, low stock count, stale count  
- Shopping list completion percentage  
- Waste stats (items/cost) where data exists  
- Engagement streaks via `EngagementStore`  

---

## 11. Pantry tab

**Screen:** `PantryView` — full inventory management

### Views & filters

- **Grid or list view** — User preference persisted  
- **Location tabs:** All, Fridge, Shelf  
- **Attention modes:** Expiring, Low stock, Pending approval (admin)  
- **Search** by item name  
- **Sort:** Name, expiry, date added, category, quantity  

### Item states & badges

Items can appear as:

- **Active** — Normal inventory  
- **Low stock** — Below configured threshold  
- **Expiring soon** — Within expiry window  
- **Expired** — Past expiry date  
- **Stale** — No quantity update within expected usage cycle  
- **Archived** — Hidden from active inventory (auto-archive optional)  
- **Pending approval** — Awaiting admin (members)  

### Adding items (`AddItemHubSheet`)

| Method | What it does |
|--------|----------------|
| **Quick add recent** | Re-add recent pantry items (1 tap = +1 unit) |
| **Catalog search** | Search `grocery_catalog`; tap to add with defaults |
| **Snap to add** | Camera photo → on-device **product recognition** (Vision + OCR); suggests name/category (Premium: `photoUploads`) |
| **Add manually** | Full form: name, quantity, unit, category, storage, expiry, cost |

**Barcode / Open Food Facts:** Service and catalog matching exist in codebase; primary add hub emphasizes search + photo. Barcode scans metered under subscription (`barcodeScansPerMonth`).

**Household barcode labels:** After saving an item from a barcode flow, household can remember `barcode → name + catalog_id` for faster rescans.

### Editing & removing items

- Tap item → **Add/Edit pantry item** form  
- **Removal flow:** Used | Remove from list | Expired | Waste  
- **Waste** optionally records estimated cost → `WasteEvent` for analytics  
- **Undo delete** — Brief window to restore deleted item  
- **Bulk select** — Multi-delete (Premium: `bulkOperations`)  

### Other pantry features

- **Pantry review** — Walk through stale items; record outcomes  
- **Expiry calendar** — Calendar of items expiring soon  
- **Duplicate awareness** — Used when adding to shopping list (not on pantry tab directly)  
- **Auto-archive** — Settings: archive expired items after grace period (default 3 days)  
- **Realtime observe** — Pantry updates when household changes data  

### Pantry item fields

Name, quantity, unit, category, storage location (fridge/shelf), expiry date, cost per unit, low stock threshold, approval status, usage/reminder metadata, optional photo path.

---

## 12. Shop tab (shopping lists)

**Screen:** `ShoppingListsView` — list hub + inline active list

### Shopping lists

- **Multiple lists** per household (count limited on free tier)  
- **Active list** expanded on hub with progress bar (completed/total)  
- **Create list** — Name new list (permission: admin/owner)  
- **Delete list** — Admin/owner  
- **List detail** — Full-screen list with all items  

### Adding items to a list

- **Inline search** with **catalog suggestions** (ranked, deduped)  
- **Free-text add** — Type name and submit  
- **Catalog pick** — `CatalogSearchSheet` for browse/search  
- **Duplicate warning** — If name matches pantry item: shows quantity + “already in pantry” with confirm dialog  
- **Duplicate merge on list** — Same catalog product or matching name → increment quantity instead of new row  

### Shopping item fields

Name, quantity, unit, category, completed flag, transferred flag, catalog link (`catalog_item_id`), approval status (members → pending).

### While shopping

- **Check off items** — Toggle completed (approved items only)  
- **Quantity steppers** — Adjust count per line  
- **Filter/search** within list  
- **Complete all** — Mark all pending approved items done  
- **Member pending items** — Visible to submitter; admins approve via approvals flow  

### Transfer to pantry (`TransferFlowSheet`)

When items are checked off:

1. **Transfer banner** on list detail — “Ready for pantry”  
2. **Transfer sheet** includes:  
   - **Pantry audit** — Flags items that already exist in pantry (merge vs new row guidance)  
   - **Trip total** — Required amount for budget (`ShoppingTrip`, `cost_logged`)  
   - **Per-item cards** — Edit quantity, unit, optional expiry before confirm  
3. **Confirm transfer** — Creates/updates pantry rows, marks shopping lines transferred, logs trip for budget  

This is GrubShelf’s signature workflow: **shop → transfer → pantry updates without re-typing**.

### Shopping list widget

See [§16 Home Screen widget](#16-home-screen-widget).

---

## 13. Expense tab (budget & insights)

**Screen:** `InsightsView` — labeled **“Expense”** in tab bar

### Budget

- **Weekly or monthly** budget period  
- **Currency** — GBP, USD, EUR, JPY, AUD (settings + finance profile)  
- **Budget settings sheet** — Set amount, period, currency (admin/owner edit; others may view)  
- **Progress UI** — Spent vs remaining for current period  
- **Budget reminders** — Local notification when close to limit (toggle in Settings)  

### Log purchase (`ReceiptFlowSheet`)

Single sheet for logging grocery spend:

| Path | What it does |
|------|----------------|
| **Scan receipt** | Camera → OCR (`ReceiptOCRService`) → parse lines + total (`ReceiptParser`) → confirm → logs **one budget trip** (lines are sanity-check only, not added to pantry) |
| **Manual entry** | Enter amount + optional store name → logs trip |

**Honest copy:** Receipt lines help verify the scan; they do not auto-populate pantry (by design — receipt is for **budget**, transfer is for **inventory**).

### Retroactive trip cost

If a transfer happened without a total, Expense tab can prompt to **add trip cost** later.

### Analytics cards

User-customizable cards (`AnalyticsPreferences`); default set includes Smart Tips, Waste Tracker, Monthly Spend, etc.

| Card | Purpose |
|------|---------|
| Smart Tips | Personalized tips from pantry state |
| Waste Tracker | Waste vs prior period |
| Monthly Spend | Spending trend |
| Items by Category | Category breakdown |
| Most / Least Purchased | Frequency insights |
| Most / Least Wasted | Waste patterns |
| Most Spent by Item / Category | Cost concentration |
| Shopping Efficiency | List completion metrics |
| Low Stock / Expiring Soon | Pantry urgency counts |
| Pantry Value | Estimated inventory value |
| Average Trip Cost | Mean spend per trip |
| Achievements | Engagement badges |

**Analytics history depth** limited on free tier (`analyticsDays`); unlimited on Premium.

### Export from Expense tab

- **Export CSV / JSON** — Pantry, shopping, waste events (Premium: `exportReports`)  
- Share via system share sheet  

---

## 14. Profile & settings

### Profile (`ProfileView`)

- Display name, household name, role badge  
- **Edit profile** — Change name; admin can edit household name  
- **Family preview** — Member list snippet  
- **All members & invites** → `FamilyMembersView`  
- **Settings** entry  
- **Upgrade to Premium** (if free)  
- **Export data** (Premium gate)  
- **Sign out**  
- **Delete account** — Destructive; server-side data deletion  
- **Rate app** — StoreKit review prompt  

### Family members (`FamilyMembersView`)

- List members with roles (owner, admin, member, guest)  
- **Invite member** — Email invite sheet + share link sheet  
- **Change role** — Owner only  
- **Remove member** — Admin/owner per rules  
- **Pending invites** — Resend, revoke  
- **Transfer ownership** — Owner only  

### Settings (`SettingsView`)

| Section | Options |
|---------|---------|
| **Appearance** | System / Light / Dark |
| **Pantry** | Auto-archive expired; grace period (1–30 days) |
| **Notifications** | Push status; expiry, low stock, usage, budget toggles; email digest |
| **Currency** | Display currency for costs/budget |
| **Premium** | Upgrade entry → paywall |
| **Help & Info** | Widget guide, widget list picker, FAQ, About, Terms, Privacy |

---

## 15. Notifications

### Local notifications (on-device)

Planned by `NotificationPlanner` from pantry, shopping, and budget state:

| Type | Trigger |
|------|---------|
| **Expiry urgent** | Items expiring today |
| **Daily digest** | Batch: expiring, low stock, stale, budget low, shopping reminder |
| **Budget low** | Near spending limit |
| **Usage / stale** | Items not updated in expected cycle |
| **Onboarding milestones** | First transfer, day-7 open, etc. |

**Smart skip:** Digest skipped if user already opened app after digest hour or reviewed expiring items today.

**Tap actions** navigate to: Pantry (expiring/low stock/review), Shop tab, or Pending approvals.

### Push notifications (remote)

- APNs device token stored in Supabase  
- Server edge function `send-push` for household events (e.g. approvals)  
- Production vs sandbox entitlements per build type  

### Email digest

Optional daily email (Supabase `send-daily-digest`) — expiring, low stock, budget summary; toggle in Settings.

### Permission primer

First-run sheet explains notifications before system permission prompt (admin/household managers).

---

## 16. Home Screen widget

**Widget:** `ShoppingListWidget` — Shopping list snapshot

### Sizes

- **Small** — List name + pending count  
- **Medium / Large** — Pending items with check-off controls  

### Behavior

- Reads snapshot from App Group (`ShoppingListWidgetDataStore`)  
- **Toggle items complete** from widget (queued sync back to app)  
- **Widget list picker** in Settings — Choose which list the widget displays  

Guide: `HomeScreenWidgetGuideView` in Settings.

---

## 17. Premium subscription

**StoreKit 2** — Monthly and yearly products; synced to Supabase `user_subscriptions`.

### Free vs Premium (enforced by `FeatureGateService`)

| Feature key | Free (typical) | Premium |
|-------------|----------------|---------|
| `pantry_items` | Limited count | Unlimited |
| `shopping_lists` | Limited count | Unlimited |
| `household_members` | Limited | Unlimited |
| `barcode_scans_per_month` | Limited (e.g. 20/mo) | Unlimited |
| `analytics_days` | Limited history (e.g. 7 days) | Full history |
| `export_reports` | Off | CSV & JSON export |
| `photo_uploads` | Off | Snap-to-add photo recognition |
| `bulk_operations` | Off | Pantry multi-select delete |

Exact numeric limits come from `subscription_plans` in Supabase (see `SubscriptionPlan` / `FeatureLimits`).

### Paywall (`PaywallView`)

- Shown when limit hit or user taps Upgrade  
- Lists premium benefits; purchase / restore  
- Premium intro during onboarding (informational, skippable)  

---

## 18. Integrations & data sources

| Integration | Use |
|-------------|-----|
| **Supabase** | Auth, Postgres, RLS, RPCs, Realtime, Edge Functions |
| **Open Food Facts** | Barcode → product name/category (rate-limited, TLS pinned) |
| **Grocery catalog** | Household-agnostic product search (`grocery_catalog` table) |
| **Apple Vision** | Receipt OCR, product photo recognition, receipt parsing |
| **Sign in with Apple / Google** | OAuth providers |
| **StoreKit 2** | Subscriptions |
| **APNs** | Push notifications |
| **App Groups** | Widget data sharing |

### Edge functions (server)

- `send-household-invite` — Invite emails + deep links  
- `send-daily-digest` — Email summaries  
- `send-push` — Push delivery  
- `expire-subscriptions` — Subscription expiry fallback  

---

## 19. Privacy, export & account control

- **No selling user data** — Stated in App Store copy and Privacy policy in-app  
- **Household-scoped data** — RLS ensures members only see their household  
- **Export** — JSON (full structured export) or CSV (pantry, shopping, waste)  
- **Delete account** — Removes user data via server RPC; signs out locally  
- **Audit logs** — Server-side for sensitive actions (see [AUDIT_LOGS.md](./AUDIT_LOGS.md))  

---

## 20. Technical platform notes

- **iOS:** SwiftUI, iOS 17+ target  
- **Architecture:** MVVM, `@Observable` view models, repository pattern  
- **Backend:** Supabase PostgreSQL with migrations in `supabase/migrations/`  
- **Design system:** `BrandColors`, `BrandTypography`, `AppSpacing`, semantic color tokens (light/dark)  
- **Offline:** Read/cache behavior; permissive feature gates when subscription check fails offline  
- **Beta telemetry:** `BetaTelemetryService` — milestone events (e.g. first transfer, day-7 open)  

---

## 21. Planned / design-only features

Documented in product backlog or design specs but **not fully shipped** as primary flows:

| Feature | Status |
|---------|--------|
| **In-store price / tag scanning** | Design spec: [IN_STORE_SCAN_LOGIC.md](./IN_STORE_SCAN_LOGIC.md) |
| **Shop mode** (large-type in-aisle UI) | Backlog P1 |
| **Dedicated live barcode scanner UI** | Services exist; not primary in Add hub |
| **Store price comparison across retailers** | Research Task #11; needs per-item price data |
| **Meal planning / recipes** | Research roadmap |
| **Android / web companion** | Not built |
| **StockUpFlowView** | Alternate first-pantry flow; superseded by PostOnboardingSetup for main path |

---

## 22. Related documentation

| Document | Contents |
|----------|----------|
| [APP_SCREEN_MAP.md](./APP_SCREEN_MAP.md) | Screen inventory |
| [APP_DESCRIPTION.md](../APP_DESCRIPTION.md) | App Store listing copy |
| [PERMISSIONS.md](./PERMISSIONS.md) | Permission matrix |
| [ROLES.md](./ROLES.md) | Role definitions |
| [DEEP_LINKING.md](./DEEP_LINKING.md) | Invite deep links |
| [IN_STORE_SCAN_LOGIC.md](./IN_STORE_SCAN_LOGIC.md) | Future scan-to-list design |
| [TESTFLIGHT_BETA_GUIDE.md](./TESTFLIGHT_BETA_GUIDE.md) | Beta tester guide |
| [PREMIUM_FEATURES_IMPLEMENTATION.md](./PREMIUM_FEATURES_IMPLEMENTATION.md) | Subscription implementation detail |
| [functional-product-backlog.md](../.taskmaster/docs/functional-product-backlog.md) | Shipped vs remaining tasks |

---

## One-sentence summary

**GrubShelf helps households see what they have, buy only what they need, move groceries into a shared pantry after shopping, and understand what food costs — together.**

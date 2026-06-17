# PRD: Notification-First Pivot

## Problem

GrubShelf has strong infrastructure (pantry tracking, notifications, household sync, receipt scanning) but low daily usage. Even the creator doesn't use it regularly. The app feels like a chore to maintain rather than a helpful assistant.

The core issue: the app is built around **manual management** (open app → check pantry → update items) instead of **proactive assistance** (app watches your food → tells you what matters).

## Vision

GrubShelf becomes a "food awareness assistant" that works in the background. The user's main interaction is:
1. Log groceries when they get home (low friction)
2. Receive a daily briefing about what needs attention
3. Open the app only when a notification tells them to

The app works for 1 person, 2 people, or a full household — the notification-first model scales naturally.

## Target Users

- Solo adults who waste food because they forget what's in the fridge
- Couples who shop separately and buy duplicates
- Families/flatmates who share a kitchen and need shared awareness

## Changes

### 1. Streamline Onboarding

**Current flow (5 screens before first use):**
1. Feature story carousel (5 chapters)
2. Premium vs Free comparison
3. Name confirmation (OAuth only)
4. Create/join household
5. Post-onboarding setup tasks (create list, invite member, set budget)

**New flow (3 screens):**
1. Sign in / sign up (existing)
2. Name your household (existing — keep as-is, this creates ownership)
3. Stock-up flow (NEW — described below)

**What gets removed from upfront onboarding:**
- Feature story carousel → delete entirely. Users discover value by using, not reading.
- Premium intro → move to Settings tab and show as a banner after 7 days of use.
- Post-onboarding setup tasks → remove screen. Shopping list creation and member invites happen organically from the main app.
- Name gate (OAuth) → keep but integrate into the household creation screen instead of being a separate screen.

**What stays unchanged:**
- The create/join household screen with the name field
- The invite acceptance flow for users who received an invite link

### 2. New "Stock Your Kitchen" First-Run Flow

**Purpose:** Get 5-15 items into the pantry within the first 60 seconds so the app has data to work with.

**Screen design:**
- Header: "What's in your kitchen right now?"
- Grid of common category buttons: Dairy, Meat, Produce, Bread, Drinks, Frozen, Snacks, Condiments
- Tapping a category shows a scrollable list of common items in that category (sourced from the existing grocery catalog)
- Each item has a one-tap "+" button that adds it with sensible defaults (quantity: 1, default expiry based on category — e.g., milk = 7 days, bread = 5 days, frozen = 90 days)
- User can also type to search (reuses existing catalog search)
- Bottom bar shows count: "8 items added" with a "Done" button
- After tapping "Done", transition to notification permission screen

**Data source:** Use the existing `grocery_catalog` table. Group by category. Show the top ~10-15 most common items per category based on general popularity (can be a static curated list initially).

**Default expiry logic:** New helper that maps category → typical shelf life in days. This auto-fills the expiry date so users don't have to think about it. Users can always edit later.

### 3. Notification Permission with Context

**When:** Immediately after the stock-up flow (user just added items).

**Screen design:**
- Icon: bell or shield
- Headline: "We'll watch your food for you"
- Subtext: "Get a daily update on what's expiring and what's running low. No spam — just what matters."
- Primary button: "Enable Reminders" → triggers iOS notification permission prompt
- Secondary link: "Maybe later" → skips, can enable from Settings

**Why this placement works:** The user just added items with expiry dates. The ask is immediately relevant — "we'll remind you about those items you just added."

### 4. Richer Daily Digest Notification

**Current:** Single-line title like "Bread expires tomorrow" with a secondary body.

**New format — daily briefing style:**

**Title:** "Your kitchen today"
**Body:** "12 items tracked. Milk expires tomorrow, chicken in 2 days. 3 items running low."

If nothing is urgent:
**Title:** "Your kitchen looks good"
**Body:** "12 items tracked, nothing expiring this week."

**Rules:**
- Always include total item count (gives a sense of the app doing its job)
- Lead with the most urgent expiry
- Mention low-stock count if any
- Keep body under 120 characters so it's fully visible on lock screen
- If zero items tracked, don't send (avoids reminding inactive users that the app is empty)

**Implementation:** Modify `NotificationPlanner.buildDigestContent()` to use the new format. The prioritization logic (expiry > low stock > shopping > budget) stays the same, but the presentation changes.

### 5. Move Premium Upsell

**Current:** Shown during onboarding before the user has used the app.

**New:**
- Remove PremiumIntroView from the onboarding sequence
- Show a non-intrusive "Upgrade" banner in Settings
- After 7 days of active use (tracked via EngagementStore), show a one-time modal highlighting premium features with usage context: "You've tracked 45 items this week. Upgrade for unlimited items, barcode scans, and data export."
- The 7-day trigger uses the existing `EngagementStore.recordAppOpen()` data

### 6. Simplify the Dashboard for Notification-First

**Current dashboard** has: health score hero, insights carousel (6 cards), contextual alerts, pantry/shopping/budget summary cards, review card.

**Proposed changes:**
- Keep the health score hero (it's a good at-a-glance summary)
- Keep the expiring/low-stock contextual alerts (these are actionable)
- Simplify the insights carousel — remove the 6-card carousel, show only the 1-2 most relevant insights inline
- Keep pantry/shopping summary cards
- Move budget details into the Insights tab (don't remove the tab, just de-emphasize budget on the home screen)
- Add a prominent "I just went shopping" button on the dashboard that opens the stock-up/add-items flow — this is the primary action the app wants users to take

### 7. "I Just Went Shopping" Quick-Entry

**Purpose:** The main moment a user interacts with the app is after a shopping trip. Make this as fast as possible.

**Implementation:**
- Prominent card or button on the dashboard: "Log your groceries"
- Tapping it opens the existing AddItemHubSheet but with the quick-add section expanded and the receipt scanner prominent
- After adding items, show a brief confirmation: "12 items added. We'll track expiry dates for you."
- This replaces the need for users to "remember to open the app" — the daily digest notification can include a reminder on shopping days: "Shopping day! Don't forget to log what you bought."

## What Does NOT Change

- The core pantry tracking data model (PantryItem, expiry dates, quantities, categories)
- The household/roles/permissions system (it works, just not front-and-center for solo users)
- The shopping list feature (stays as a tab)
- The notification infrastructure (NotificationPlanner, push delivery, deep linking)
- The receipt scanner and barcode lookup
- The approval workflow (stays for households that want it)
- Backend/Supabase schema — no migrations needed for this pivot

## Success Metrics

- **Notification opt-in rate:** >70% of new users enable notifications during onboarding
- **Day-7 retention:** Users who receive daily digests return at >40% vs current baseline
- **Items added in first session:** Average >5 items (currently unknown but likely low)
- **Daily digest open rate:** >30% of notifications result in app opens
- **Time to first value:** Under 2 minutes from app install to first items tracked

## Implementation Order

1. New stock-up flow (highest impact — gets data into the system)
2. Streamline onboarding (remove carousel + premium intro)
3. Notification permission screen with context
4. Richer daily digest format
5. Dashboard "Log your groceries" button
6. Move premium upsell to 7-day trigger
7. Dashboard simplification

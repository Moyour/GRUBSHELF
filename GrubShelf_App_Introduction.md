# Introducing GrubShelf

**Reduce waste. Save money. Simplify meals.**

GrubShelf is a modern household pantry and shopping app built to help families stay organized, cut unnecessary grocery spending, and waste less food. Instead of guessing what is at home or buying duplicates, GrubShelf gives you one shared place to track pantry items, plan shopping, log spending, and act early on expiry and low-stock alerts.

Designed for real life, GrubShelf combines inventory management, collaborative shopping, and budget insights in a clean iOS experience so daily food decisions become easier and smarter.

---

## What GrubShelf Does

GrubShelf helps households manage the full food cycle:

- Track what you already have in your pantry
- Plan what to buy with shared shopping lists
- Move completed shopping into pantry inventory
- Monitor spending and budget progress
- Reduce waste with reminders before items expire
- Coordinate with family members in one household space

---

## Core Features

### Smart Authentication and Onboarding

Get started quickly and securely with:

- Sign in with Apple
- Sign in with Google
- Email/password authentication

New users are guided through onboarding, household setup, and adding their first item.

### Pantry Management

Your pantry becomes a live inventory system:

- Add items by barcode scan, catalog search, or manual entry
- Search and filter by all, expiring, low stock, and category
- Track item states (active, low stock, expiring soon, expired, stale, archived)
- Mark removed items as Used or Wasted (with optional waste cost)
- Configure auto-archive behavior for expired items

### Shopping Lists That Sync With Pantry

Plan better and avoid duplicate purchases:

- Create and manage multiple shopping lists
- Add items with catalog suggestions
- Check off items as you shop
- Transfer completed items to pantry with editable quantity and optional expiry info
- Record trip costs during transfer for better financial tracking

### Dashboard Overview

See your household status at a glance:

- Pantry health score
- Engagement streaks
- Quick actions (Add Item, Shopping, Log Purchase)
- Expiry, low stock, and to-buy metrics
- Budget snapshot and shopping progress

### Insights and Budget Tracking

Turn your food activity into actionable financial insight:

- Set weekly or monthly budget
- Choose your preferred currency
- Log purchases (amount, date, store)
- Monitor spend vs. budget progress
- Review analytics like trends, savings, and waste impact
- Customize visible analytics cards

### Household Collaboration

Built for families and shared living:

- Create or join a household
- Invite members
- View roles (admin/member)
- Manage pending invites
- Share responsibility for pantry and shopping workflows

### Settings, Notifications, and Data Controls

GrubShelf supports personal preferences and trust:

- Light, dark, or system theme
- Expiry, low-stock, and usage reminders
- Pantry behavior controls (including auto-archive grace period)
- Data export for pantry and shopping records
- Account controls including sign out and account deletion

---

## How It Works in Practice

A typical flow in GrubShelf:

1. Sign in and set up your household
2. Add pantry items (scan, search, or manual)
3. Create shopping lists as needs arise
4. Check off purchases while shopping
5. Transfer completed items into pantry inventory
6. Log costs and review spending insights
7. Act on expiry and low-stock reminders to reduce waste

This loop keeps your kitchen more efficient and your spending more intentional.

---

## Built For

GrubShelf is ideal for:

- Busy families coordinating groceries
- Couples or roommates sharing meal planning
- Budget-conscious households
- Anyone trying to reduce food waste and avoid duplicate purchases

---

## Color scheme

The visual identity is **teal** as the primary brand color, **warm amber** for secondary emphasis, and **soft warm neutrals** for backgrounds and typography. **Success**, **warning**, **danger**, and **info** colors keep states readable. The app uses **semantic color tokens** in the asset catalog (for example `gsBackground`, `gsBrandPrimary`, `gsAccent`) so **light and dark mode** stay aligned. Reference hex scales, full token names, and SwiftUI usage are documented in [`docs/COLOR_SCHEME_BREAKDOWN.md`](docs/COLOR_SCHEME_BREAKDOWN.md).

---

## Technology Behind the App

GrubShelf is built as a native iOS app with a modern stack:

- Platform: iOS (SwiftUI)
- Backend: Supabase (Auth, database, realtime)
- Authentication: Apple, Google, and email
- Analytics visualization: Swift Charts

---

## Why GrubShelf Matters

Most food waste and grocery overspending happen in the small daily gaps: forgotten pantry items, untracked spending, duplicated purchases, and missed expiry dates. GrubShelf closes those gaps by giving households clear visibility and simple actions.

It is not just a pantry list or a shopping list app. It is a connected household system for smarter food management from shelf to store and back again.

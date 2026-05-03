# GrubShelf — functional product backlog

**Last reviewed:** 2026-04-10

## Shipped (track here)

- [x] **P0 — Today queue on Home** — Prioritized “Today’s actions” card (max 5): expiring → low stock → shopping → budget → stale review; single place for urgent work.
- [x] **P0 — Dedup Overview sheet** — Full overview sheet hides the insights carousel (same signals as Home queue + Insights tab).

## Remaining

See sections below; check boxes as you complete work.

### P0

| Done | Task |
|------|------|
| [ ] | **Cold start** — Dedicated minimal onboarding path after first launch |

### P1 — Trust & speed

| Done | Task |
|------|------|
| [ ] | Stale / sync cues (last updated, refresh feedback) |
| [ ] | Faster add loop (recents, barcode prominence) |
| [ ] | Search: align copy with behavior (pantry vs lists) |

### P1 — Shopping

| Done | Task |
|------|------|
| [ ] | Shop mode (large type, list focus) |
| [ ] | Transfer-to-pantry clarity pass |

### P2 — Money & household

| Done | Task |
|------|------|
| [ ] | Budget row polish (only if queue feels crowded) |
| [ ] | Visible collaboration on feed |
| [ ] | Invite / “same shelf” moment |

### P3

| Done | Task |
|------|------|
| [ ] | Health score vs concrete actions |
| [ ] | High-value notifications only |

## Code references

- Home: `GrubShelf/Views/HomeRootView.swift`
- Queue ordering: `TodayQueuePlanner` in `GrubShelf/Extensions/HouseholdFeedFormatter.swift`
- Overview: `DashboardOverviewContent` in `GrubShelf/Views/Dashboard/DashboardView.swift`

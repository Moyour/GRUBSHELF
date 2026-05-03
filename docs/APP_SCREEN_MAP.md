# GrubShelf screens

- **Session loading** — Waits while the app checks whether you are signed in.

- **FeatureOnboardingView** — Intro pages about the app before sign-in; can skip or finish to continue.

- **WelcomeView** — Sign in with Google, Apple, or email.

- **EmailAuthView** — Email and password sign-in or sign-up.

- **CreateHouseholdView** — Accept a household invite or create a new household after sign-in.

- **ContentView** — Main app: switches between Home, Shop, and Expense; can open profile, settings, add item, and log purchase.

- **HomeRootView (Home tab)** — Your shelf: search, filter, list of pantry items, quick actions, and links to overview and profile.

- **Overview sheet** — Full dashboard-style summary (health, cards, shortcuts) over the home inventory.

- **ExpiryCalendarView** — Calendar-style view of items that are expiring soon.

- **PantryReviewView** — Walk through items that need a check-in (used, wasted, etc.).

- **AddItemHubSheet** — Add to pantry: search catalog, scan barcode, photo fallback, or open manual form.

- **BarcodeScannerView** — Camera barcode scan to look up a product.

- **CameraImagePicker** — Take a photo (receipt or product) full screen.

- **AddEditPantryItemView** — Create or edit one pantry item (name, quantity, expiry, category).

- **ShoppingListsView (Shop tab)** — List of shopping lists; create new lists.

- **CreateShoppingListSheet** — Name and create a new shopping list.

- **ShoppingListDetailView** — One list: add items, check off, transfer bought items to pantry, open catalog search.

- **CatalogSearchSheet** — Pick an item from the grocery catalog to add to the list.

- **ShoppingAuditView** — Match shopping items to pantry before transferring.

- **TransferConfirmationView** — Confirm moving completed shopping items into the pantry (and related bookkeeping).

- **InsightsView (Expense tab)** — Budget and analytics in one place; open settings for budget and analytics layout.

- **CustomizeAnalyticsSheet** — Choose which analytics cards to show.

- **BudgetSettingsSheet** — Budget amount, period, currency, etc.

- **LogPurchaseSheet** — Log a purchase amount, date, and store; optional receipt scan.

- **ReceiptScanSheet** — Pick or snap a receipt and process it.

- **ReceiptConfirmationSheet** — Review parsed receipt data before saving.

- **ProfileView** — Account info, household name, link to settings, family, export, sign out, delete account.

- **EditProfileSheet** — Change display name and (if admin) household name.

- **FamilyMembersView** — List members and pending invites; actions for roles and removal.

- **InviteMemberSheet** — Enter email to invite someone to the household.

- **InviteShareSheet** — System share sheet for an invite link.

- **ExportShareSheet** — Share an exported JSON or CSV file.

- **SettingsView** — Theme, pantry auto-archive, notification toggles, and links to help and legal.

- **FAQView** — Frequently asked questions.

- **AboutView** — About the app.

- **TermsView** — Terms and conditions.

- **PrivacyView** — Privacy policy.

Not wired into navigation (code exists but no current path to them):

- **PantryView** — Standalone pantry screen; the app uses Home instead.

- **AddFirstItemView** — Not referenced elsewhere.

- **DashboardGlassLayout** — Alternate layout experiment, not a user-facing route.

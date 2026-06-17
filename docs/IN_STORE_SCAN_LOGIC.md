# GrubShelf — In-Store Scan Logic (Product / Price → Shopping List)

**Status:** Design spec  
**Last updated:** 2026-06-10  
**Related code:** `OpenFoodFactsService`, `BarcodeCatalogMatch`, `GroceryCatalogSearchRanker`, `ShoppingListAddBehavior`, `household_barcode_labels`

---

## 1. Goal

When a user scans in the store (shelf tag, product label, or barcode), the app should:

1. Identify the product as accurately as possible
2. Resolve to a canonical `catalog_item_id` when possible
3. Capture price when available
4. Always require user confirmation before saving
5. Warn if the item is already in the household pantry
6. Merge with an existing shopping-list line when it's the same product

---

## 2. ID model (do not confuse these)

| ID | Meaning | Table / type |
|----|---------|----------------|
| `catalog_item_id` | Canonical product in global grocery catalog | `grocery_catalog` → `GroceryCatalogItem` |
| `shopping_items.item_id` | One row on a shopping list | New UUID per add (or quantity bump on dedup) |
| `pantry_items.item_id` | One inventory row | Matched today by **name**, not catalog UUID |
| `household_barcode_labels` | Household memory: barcode → name + optional catalog | Per-household, speeds repeat scans |

**Target of matching:** `catalog_item_id` on the shopping line.  
**Never auto-save** without a confirm sheet.

---

## 3. Scan input types

| Mode | Signals extracted | Existing building blocks |
|------|-------------------|--------------------------|
| **Shelf tag OCR** | Product name fragment, price | New `PriceTagParser`; reuse `ReceiptOCRService` / Vision |
| **Barcode** | 8–14 digit UPC/EAN | `OpenFoodFactsService.lookup` |
| **Product photo** | Label text, rough category | `ProductRecognitionService` |

### ScanDraft (internal model)

```swift
struct ScanDraft {
    var displayName: String
    var category: String?
    var priceMinor: Int?
    var barcode: String?
    var catalogSearchQuery: String
    var matchConfidence: Float
}
```

---

## 4. End-to-end flow

```
User taps Scan (shop mode)
        │
        ▼
┌───────────────────┐
│ Extract signals   │  OCR / barcode / Vision
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ Resolve product   │  Waterfall (§5)
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ Confirm sheet     │  User edits name, qty, unit, price
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ Pantry duplicate? │  ShoppingListAddBehavior.pantryMatch
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ Save to list      │  catalog line or free-text; dedup merge
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ Remember barcode  │  Upsert household_barcode_labels (if barcode)
└───────────────────┘
```

---

## 5. Product resolution waterfall

Run in order; stop at first strong hit.

### 5a. Household barcode label (highest trust for this household)

- Query `household_barcode_labels` by `(household_id, barcode)`
- If hit: prefill `displayName`, `category`, `catalog_item_id`
- Skip Open Food Facts

### 5b. Open Food Facts (barcode only, network)

- `OpenFoodFactsService.lookup(barcode)` → name, category, `catalogSearchQuery`

### 5c. Catalog search

- Search `grocery_catalog` with best query (OCR name or OFF `catalogSearchQuery`)
- Rank with `GroceryCatalogSearchRanker`

### 5d. BarcodeCatalogMatch decision

| Resolution | UI |
|------------|-----|
| `.single(catalog)` | Confirm with catalog pre-selected |
| `.chooseAmong([2–3])` | User picks: e.g. Whole milk / Semi-skimmed / Oat milk |
| `.useOpenFoodFacts(name, category)` | Free-text prefill; `catalog_item_id = nil` unless user picks catalog |

For price-tag OCR (no barcode): same catalog search; if many weak hits → show top 3 from `GroceryCatalogSearchRanker.suggestions`.

---

## 6. Confirm sheet (accuracy gate)

Always shown before any database write.

| Field | Source | Editable |
|-------|--------|----------|
| Name | Catalog / OCR / OFF / Vision | Yes |
| Quantity | Default 1 | Yes |
| Unit | Catalog `defaultUnit` | Yes |
| Price | Tag OCR | Yes (prompt if missing) |
| Category | Catalog / OFF / Vision | Yes |
| Catalog link | `catalog_item_id` if user picked a catalog row | Via suggestion chips |

**Low confidence** (`matchConfidence < 0.35` or category `Other`):

- Banner: “Double-check this item”
- Show catalog suggestion chips (same pattern as photo recognition in `AddEditPantryItemView`)

**Pantry warning** (on confirmed name):

- `ShoppingListAddBehavior.pantryMatch(in:pantryItems, name:)`
- If match: “You already have X at home — still add?”

---

## 7. Save to shopping list

### Catalog product confirmed

```swift
ShoppingItem.newCatalogLine(from: catalog, ...)  // sets catalog_item_id
```

### Free-text only

```swift
ShoppingItem.newFreeTextLine(name: ..., catalogItemId: nil)
```

### Dedup on same list (before insert)

1. If `catalog_item_id` matches an incomplete line → `adjustQuantity(+1)`
2. Else if `GroceryCatalogSearchRanker.shoppingNamesMatch` → increment quantity
3. Else → insert new row

Reference: `ShoppingListViewModel.listDuplicate` / `performAddCatalogItem`.

### Optional: link to planned list item

If list already has unchecked “Milk” and scan resolves to milk catalog:

- Offer **“Mark Milk as picked · £1.89”** instead of adding duplicate line (future enhancement).

### After confirm (barcode present)

- Upsert `household_barcode_labels` with final `display_name`, `category`, `catalog_item_id`

---

## 8. Scan mode comparison

| Mode | Identity | Price | Catalog link |
|------|----------|-------|--------------|
| Shelf tag OCR | OCR line → catalog search | From tag | Often yes |
| Barcode | Label → OFF → catalog | User or second tag scan | Strong when label/catalog hit |
| Product photo | Vision + label OCR | Usually manual | Often free-text |

**UX note:** First scan can fill name; optional “Scan price” on confirm sheet if price missing.

---

## 9. Proposed service API

Centralize in `InStoreScanResolver`:

```swift
enum ScanInput {
    case barcode(String)
    case shelfTagImage(UIImage)
    case productImage(UIImage)
}

enum ScanResolution {
    case ready(ScanDraft, catalogItem: GroceryCatalogItem?)
    case pickCatalog([GroceryCatalogItem], draft: ScanDraft)
    case manualOnly(draft: ScanDraft)
}

// InStoreScanResolver.resolve(scan:householdId:) async throws -> ScanResolution
```

`ShopScanConfirmViewModel`:

1. Takes `ScanResolution`
2. Presents confirm UI
3. Calls `addCatalogItem` / `performAddFreeText` (+ `price_minor` when schema exists)

---

## 10. Schema additions (shopping)

Add to `shopping_items` (migration TBD):

| Column | Type | Purpose |
|--------|------|---------|
| `price_minor` | INT NULL | Line price from scan |
| `scanned_at` | TIMESTAMPTZ NULL | When price was captured |
| `store_name` | TEXT NULL | Optional store context |

Running cart total = sum of `price_minor * quantity` for incomplete items on active list.

---

## 11. Freemium / metering

- Rename paywall copy: “in-store scans” (tag + product + barcode paths)
- Free tier: N scans/month (reuse `barcodeScansPerMonth` meter or new `inStoreScansPerMonth`)
- Premium: unlimited scans + price history

---

## 12. Implementation phases

| Phase | Scope |
|-------|--------|
| **P1** | Shop mode + confirm sheet + catalog waterfall + pantry warning + `price_minor` |
| **P2** | Shelf-tag OCR (`PriceTagParser`) + running total footer |
| **P3** | “Mark list item as picked” via scan + store price history |

---

## 13. Code references

| Concern | File |
|---------|------|
| Catalog line factory | `GrubShelf/Models/ShoppingItem+CatalogLine.swift` |
| List dedup | `GrubShelf/ViewModels/ShoppingListViewModel.swift` |
| Name / catalog match | `GrubShelf/Extensions/GroceryCatalogSearchRanker.swift` |
| Barcode → catalog | `GrubShelf/Services/OpenFoodFactsService.swift` (`BarcodeCatalogMatch`) |
| Pantry duplicate | `GrubShelf/Extensions/ShoppingListAddBehavior.swift` |
| Household barcode memory | `supabase/migrations/022_household_barcode_labels.sql` |
| Product photo | `GrubShelf/Services/ProductRecognitionService.swift` |
| Receipt OCR pattern | `GrubShelf/Services/ReceiptOCRService.swift`, `ReceiptParser.swift` |

---

## 14. Competitive context

Apps that already ship in-aisle price / label scanning (for reference):

| App | Approach |
|-----|----------|
| [TallyCart](https://tallycart-prod.web.app/en) | Shelf-tag OCR, offline, running total |
| [TallySnap](https://tallysnap.com/) | Tap-to-snap price tags + shopping lists |
| [ShopAndGrab](https://shopandgrab.com/) | Price tag AI + barcode + trip tracker |
| [GroceryBudget](https://grocerybudget.app/) | Label scan (no barcode), on-device, budget bar |
| [Enchlist](https://play.google.com/store/apps/details?id=com.vladlee.shoppinglist) | Photo scan of tags, products, receipts |

GrubShelf differentiation: combine in-store scan with **household pantry duplicate warnings**, **shared lists**, and **transfer-to-pantry** in one loop.

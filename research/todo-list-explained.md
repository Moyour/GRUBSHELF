1# GrubShelf — 20 Tasks Explained (Plain Language)

Everything below comes from the user research (10 interviews) and competitive analysis (8 competing apps studied). Each task explains WHAT it is, WHY it matters, and a REAL EXAMPLE so you can understand it.

---

## CRITICAL — Must Do Before Launch

---

### Task #1: Redesign Onboarding to "Pantry Builds Itself"

**What it is:**
Right now, when someone opens GrubShelf for the first time, they need to add items to their pantry — scan barcodes, search the catalog, or type them in manually. This feels like homework. People quit apps that feel like homework.

The fix: Instead of asking users to set up their pantry on day one, let them start by making a shopping list (something everyone already does). Then when they finish shopping and transfer items to the pantry, the pantry fills itself automatically. After 2-3 shopping trips, they have a full pantry without ever "setting it up."

**Why it matters:**
Every single person we interviewed (10 out of 10) said they would stop using an app if it feels like too much work to set up. This is the #1 reason pantry apps fail — people download them, see they need to enter 50 items, and delete the app.

**Real example:**
Imagine you download a new app and it says "Add all the food in your kitchen to get started." You look at your full fridge and pantry and think "no way" and close the app. But if it says "What do you need from the store?" — that's easy. You type milk, eggs, bread. You go shopping. You come back and tap "transfer to pantry." Now your pantry has 3 items without any effort. Next week, 10 items. The pantry grows on its own.

---

### Task #2: Strengthen Duplicate Purchase Warnings

**What it is:**
When someone adds "milk" to a shopping list, and there's already milk in the pantry, show a big clear warning: "You already have 2 milk at home. Still need more?" This feature partially exists in GrubShelf already — this task is about making it louder and more helpful.

**Why it matters:**
7 out of 10 people we interviewed said duplicate purchases are their biggest frustration. No competing app does this well. This is GrubShelf's unique advantage — the one feature that makes people say "this app just saved me money."

**Real example:**
One interviewee (P3) bought almond milk at the store, came home, and found a full carton hidden behind the juice in the fridge. Another (P10) said their partner "does a quick stop and buys something that's already in stock" regularly. If GrubShelf had popped up "You bought Almond Milk 3 days ago — still need more?" that purchase wouldn't have happened.

---

### Task #3: Define Freemium Pricing Strategy

**What it is:**
"Freemium" = Free + Premium. The app is free to download and use with basic features. But some advanced features require a yearly subscription (like $9.99-14.99/year).

You need to decide:
- What features are FREE (available to everyone)
- What features are PAID (require a subscription)
- How much the subscription costs

**Example of how competitors do it:**

| App | Free | Paid |
|-----|------|------|
| AnyList | Shared lists, basic features | $14.99/yr — meal planning, photos, web access |
| OurGroceries | Lists with ads | $7.99/yr — no ads, recipes |
| Pantry Check | Track 200 items | Paid — unlimited items |

**Suggested split for GrubShelf:**
- FREE: Pantry tracking, 1 shopping list, expiry alerts, barcode scanning (for 1 person)
- PAID ($9.99-14.99/year): Household sharing (invite family), unlimited shopping lists, budget tracking, insights/analytics, household roles

**Why it matters:**
You need to make money from the app. But if you charge too much or put too many features behind the paywall, nobody downloads it. If you charge too little or make everything free, you can't sustain the app. This is the balance.

You already have StoreKit code in the app (GrubShelf/Services/StoreKitService.swift) — this task is about deciding the business model, not writing code.

---

### Task #18: Prepare App Store Listing and Marketing

**What it is:**
When you submit GrubShelf to Apple's App Store, you need to fill out a "store page" — this is what people see when they search for your app. It includes:

1. **App name**: GrubShelf
2. **Subtitle**: A short tagline (e.g., "Reduce waste. Save money. Simplify meals.")
3. **Description**: A paragraph explaining what the app does and why someone should download it
4. **Screenshots**: Pictures of the app in action (dashboard, pantry, shopping list, etc.)
5. **Keywords**: Words people type when searching — like "pantry tracker", "grocery list", "food waste", "shared shopping list"
6. **Category**: Food & Drink
7. **Privacy labels**: Apple requires you to declare what data the app collects

**Why it matters:**
This is your storefront. If the description is bad or the screenshots don't show the value, people scroll past. Good App Store listings can 2-5x your download rate.

**Real example:**
If someone searches "shared grocery list" on the App Store, your app needs to show up. And when they see it, the screenshots should immediately show: "Oh, this lets my whole family share a shopping list AND tracks what's in the pantry AND tracks spending — I'll try it."

---

### Task #19: Set Up TestFlight Beta with 50-100 Users

**What it is:**
TestFlight is Apple's tool for letting people test your app before it's publicly available on the App Store. You invite 50-100 people (friends, family, people from Reddit, social media) to download and use GrubShelf for 2-4 weeks. They give you feedback and you fix problems before the real launch.

**Why it matters:**
Launching directly on the App Store without testing is risky. Beta testing lets you:
- Find bugs and crashes before real users see them
- See if people actually complete onboarding (or quit halfway)
- Get feedback on what's confusing
- Build a small group of fans who will leave positive reviews on launch day

**What you track during beta:**
- Do >60% of users add at least 5 items in their first week? (onboarding works)
- Do >40% come back after 7 days? (app is useful)
- Do >30% invite a household member? (sharing works)

You already have TestFlight docs in the project: docs/TESTFLIGHT_BETA_GUIDE.md

---

### Task #20: Add Privacy and Data Security Messaging

**What it is:**
This is NOT a chat feature or messaging system. It's a simple line of text inside the app that says something like:

> "Your data is private. We never sell your information to advertisers."

You put this on the welcome screen, in settings, or in the App Store description. That's it — just text.

**Why it matters:**
One interviewee (P1, a family user) said: "I'm a bit cautious about how my data is used or shared, especially spending info. I'd want clear privacy policies." People are nervous about apps that track their spending and food habits. A simple reassurance builds trust.

Competitor Groceries Tracker uses this as a selling point: "Unlike most budgeting apps that sell data to advertisers, we don't."

**This is optional and low effort** — literally just adding a text label. Can be skipped or done later.

---

## HIGH PRIORITY — First Update After Launch

---

### Task #4: Improve Receipt Scanning as Primary Add-to-Pantry Path

**What it is:**
GrubShelf already has receipt scanning. This task is about making it the MAIN way people add items — not barcode scanning (which requires scanning each item one by one).

The flow: You finish shopping → snap a photo of your receipt → the app reads all items and prices → you tap "confirm" → everything goes into your pantry at once.

**Why it matters:**
Scanning one receipt takes 10 seconds. Scanning 20 individual barcodes takes 5+ minutes. Groceries Tracker built their entire business around receipt scanning and it works.

**Real example:**
You come home with 15 grocery bags. Option A: Pull out each item, find the barcode, scan it, put it away. (Nobody does this.) Option B: Take one photo of the receipt, tap confirm, done. Option B wins.

---

### Task #5: Add "Use It Up" Recipe Suggestions

**What it is:**
When food is about to expire, suggest a recipe that uses it. For example: "Your spinach expires in 2 days — try this spinach pasta recipe?"

Doesn't need to be a full recipe app. Can start simple: just link to a Google search or recipe website for that ingredient.

**Why it matters:**
Knowing food is expiring is only half the problem. People also need to know what to DO with it. 3 out of 10 interviewees specifically asked for this. Clove AI's biggest feature is AI recipe suggestions from pantry items.

**Real example:**
P10 had baby carrots go rubbery because they forgot about them. If GrubShelf had sent a notification saying "Your carrots expire tomorrow — try this quick carrot soup recipe?" they might have cooked them instead of throwing them away.

---

### Task #6: Add Siri Shortcuts

**What it is:**
Let people use their voice to interact with GrubShelf:
- "Hey Siri, add milk to my GrubShelf list"
- "Hey Siri, what's expiring this week?"

**Why it matters:**
AnyList and OurGroceries both support Siri/Alexa. When you're cooking with messy hands or driving home from work, you can't type. Voice is the fastest way to add items.

**Real example:**
You're cooking dinner and realize you're almost out of olive oil. Instead of washing your hands, picking up your phone, opening the app, and typing — you just say "Hey Siri, add olive oil to my shopping list." Done in 3 seconds.

---

### Task #7: Improve Expiry Alert Timing and Intelligence

**What it is:**
GrubShelf already sends expiry notifications. This task makes them smarter:
- Fresh items (spinach, chicken): Alert 2 days before expiry
- Long-life items (ketchup, canned food): Alert 1 week before
- Group multiple expiring items in ONE notification (not 5 separate ones)
- Add a "Use It Up" section on the dashboard

**Why it matters:**
10/10 interviewees said expiry alerts are the most valuable feature. But bad alerts (too many, wrong timing, no actionable info) are worse than no alerts. Nobody wants 10 notifications a day.

**Real example:**
Instead of getting: "Spinach expires tomorrow" + "Chicken expires tomorrow" + "Yogurt expires tomorrow" — you get ONE notification: "3 items expiring soon: Spinach, Chicken, Yogurt — tap to see Use It Up suggestions."

---

## MEDIUM PRIORITY — V2 (Version 2) Roadmap

---

### Task #8: Build "Pantry Score" / Food Waste Analytics

**What it is:**
A dashboard that shows how well you're managing food:
- "This month you used 85% of your food and wasted 15%"
- "You saved $23 by avoiding duplicate purchases"
- "You wasted $18 worth of expired food"
- A score or trend graph over time

GrubShelf already tracks Used vs. Wasted when you remove items — this task turns that data into visible insights.

**Why it matters:**
Clove AI has a "Pantry Score" feature that users love. The average US household wastes $1,500/year in food. Showing people their personal number motivates behavior change and keeps them using the app.

---

### Task #9: Plan Android or Web Companion

**What it is:**
GrubShelf only works on iPhone. If one person in the household has an Android phone, they can't use GrubShelf at all — which breaks the whole "shared household" concept.

This task is about PLANNING (not building yet) how to support non-iPhone users. Simplest option: a website where Android users can view the pantry and shopping list in a browser.

**Why it matters:**
AnyList, OurGroceries, and most competitors work on both iPhone and Android. This is the single biggest thing limiting who can use GrubShelf.

---

### Task #10: Add Basic Meal Planning

**What it is:**
A weekly view where you plan meals (Monday: pasta, Tuesday: stir fry). The app checks what ingredients you already have in the pantry and creates a shopping list of only what's missing.

**Why it matters:**
AnyList, Clove AI, and KitchenPal all have meal planning. Interviewees said unexpected changes to meal plans are a major cause of food waste.

**Real example:**
You plan chicken stir fry for Wednesday. GrubShelf checks: "You have chicken and soy sauce but need broccoli and rice." It adds broccoli and rice to your shopping list automatically.

---

### Task #11: Store Price Comparison

**What it is:**
After scanning receipts from different stores over time, show which store is cheapest for which products. "Dairy is 20% cheaper at Aldi than Walmart."

**Why it matters:**
Groceries Tracker's most popular feature. Users can save 10-20% by knowing which store to buy what from.

**Depends on:** Task #4 (receipt scanning) needs to work well first.

---

### Task #15: Optimize Real-Time Sync Performance

**What it is:**
When one household member checks off "milk" on the shopping list, the other member should see it disappear within 1-2 seconds on their phone. Test and optimize this.

**Why it matters:**
OurGroceries is famous for "fastest sync." If GrubShelf's sync feels slow, people switch back to Apple Reminders or OurGroceries.

---

### Task #16: Simplify Household Invite Flow

**What it is:**
Make it dead simple to invite your partner/roommate/family member. One-tap share link via iMessage. The new member sees "Welcome! Your household already has 15 pantry items" and can immediately use the shopping list.

**Why it matters:**
If inviting someone is complicated, they won't join. If joining is confusing, they won't stay. The app only works when the whole household uses it.

**Real example:**
P3 (roommates): "If it just worked without needing everyone to do much, like one person sets it up and it runs quietly, that'd be ideal."

---

### Task #17: "Shared Basics" for Roommates

**What it is:**
Let roommates mark items as "shared" (milk, eggs, toilet paper) vs "personal" (my protein bars). Shared items are visible to everyone. Personal items are private.

**Why it matters:**
Roommates don't share everything. If the app forces everyone to see everyone's food, it feels intrusive. This was specifically requested by the roommate participant.

---

## LOW PRIORITY — Future Ideas

---

### Task #12: AI Photo Scanning

**What it is:**
Take a photo of your fridge shelf → AI identifies all the items → adds them to pantry automatically. Like Clove AI does.

**Why it matters:**
Solves the "hidden items in the back of the fridge" problem. But technically very complex to build well.

---

### Task #13: Instacart Integration

**What it is:**
One-tap button to order your entire shopping list through Instacart (grocery delivery service). You never have to leave GrubShelf.

**Why it matters:**
Honeydew has this. Convenience for people who use grocery delivery.

---

### Task #14: Smart Restock Predictions

**What it is:**
The app learns your buying patterns and predicts when you'll run out. "You buy milk every 8 days — it's been 7 days. Add to list?"

**Why it matters:**
No competitor does this well yet. Would feel "magical" but needs months of purchase data to work accurately.

---

## Summary Table

| # | Task | Priority | Type |
|---|------|----------|------|
| 1 | Redesign onboarding ("Pantry Builds Itself") | CRITICAL | Code change |
| 2 | Strengthen duplicate purchase warnings | CRITICAL | Code change |
| 3 | Define freemium pricing (what's free vs paid) | CRITICAL | Business decision |
| 18 | Write App Store description, screenshots, keywords | CRITICAL | Marketing |
| 19 | TestFlight beta test with 50-100 people | CRITICAL | Testing |
| 20 | Add "We don't sell your data" text in app | CRITICAL (optional) | Trust / text only |
| 4 | Make receipt scanning the main way to add items | HIGH | Code change |
| 5 | Suggest recipes when food is about to expire | HIGH | New feature |
| 6 | Siri voice commands ("add milk to my list") | HIGH | New feature |
| 7 | Smarter expiry alerts (timing, grouping) | HIGH | Code improvement |
| 8 | Pantry Score / waste analytics dashboard | MEDIUM | New feature |
| 9 | Plan Android or web version | MEDIUM | Planning |
| 10 | Meal planning connected to pantry | MEDIUM | New feature |
| 11 | Show which store is cheapest (from receipts) | MEDIUM | New feature |
| 15 | Make sure sync between devices is fast | MEDIUM | Code improvement |
| 16 | Make inviting household members easier | MEDIUM | Code improvement |
| 17 | Shared vs personal items for roommates | MEDIUM | New feature |
| 12 | AI photo scanning of fridge shelves | LOW | Future feature |
| 13 | Instacart grocery delivery integration | LOW | Future feature |
| 14 | Predict when you'll run out of items | LOW | Future feature |

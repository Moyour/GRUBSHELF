# Upload GrubShelf to TestFlight

**Version:** 1.0.0 (build **2**)  
**Bundle ID:** `com.grubshelf.GrubShelf`

## Before you upload

1. [ ] `GrubShelf/Config.plist` exists locally (gitignored) with real Supabase + Google keys
2. [ ] Unit tests green: `xcodebuild test -scheme GrubShelf -destination 'platform=iOS Simulator,name=iPhone 17'`
3. [ ] App created in [App Store Connect](https://appstoreconnect.apple.com) with bundle ID `com.grubshelf.GrubShelf`
4. [ ] Push: Supabase APNs secrets use **production** for TestFlight (`APNS_USE_SANDBOX=false`)
5. [ ] Rotate service_role if it was ever committed ([SECURITY_ROTATION.md](SECURITY_ROTATION.md))

Release builds use **production** push entitlements (`GrubShelfRelease.entitlements`). Debug/simulator still use development.

## Option A — Xcode (recommended first time)

1. Open `GrubShelf.xcodeproj`
2. Select **Any iOS Device (arm64)** (not a simulator)
3. **GrubShelf** target → **Signing & Capabilities** → Team + “Automatically manage signing”
4. Same for **GrubShelfWidget**
5. **Product → Archive**
6. Organizer → **Distribute App** → **App Store Connect** → **Upload**
7. Wait for processing in App Store Connect → **TestFlight**

## Option B — Command line

After setting Team in Xcode once (or export `DEVELOPMENT_TEAM`):

```bash
chmod +x scripts/upload_testflight.sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/upload_testflight.sh
```

## Add testers

1. App Store Connect → your app → **TestFlight**
2. **Internal testing** — up to 100 team members (fastest)
3. **External testing** — requires Beta App Review (first build)

Share the public link or invite emails from TestFlight.

## After upload

- Run smoke test on a **physical device** via TestFlight (push, camera, Sign in with Apple)
- Log feedback in [REGRESSION_EXECUTION_LOG.md](REGRESSION_EXECUTION_LOG.md)
- Beta guide for testers: [TESTFLIGHT_BETA_GUIDE.md](TESTFLIGHT_BETA_GUIDE.md)

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No signing certificate | Xcode → Settings → Accounts → download certificates |
| Missing compliance | App Store Connect → export compliance (usually “No” for encryption if using HTTPS only) |
| Invalid entitlements | Ensure App ID has Push, Sign in with Apple, App Groups |
| Config missing at runtime | Confirm `Config.plist` is in target **Copy Bundle Resources** |
| Push not received on TestFlight | Production APNs + `aps-environment` production in release build |

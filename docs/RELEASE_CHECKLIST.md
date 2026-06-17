# Release checklist (GrubShelf v1)

Single source of truth for shipping. Complete in order.

## 1. Security (stop-ship)

- [ ] Rotate Supabase **service_role** if it was ever committed ([SECURITY_ROTATION.md](SECURITY_ROTATION.md))
- [ ] Vault `service_role_key` set in production (not placeholder)
- [ ] Edge functions deployed: `send-household-invite`, `send-daily-digest`, `send-push`
- [ ] `send-daily-digest` / `send-push` reject calls without service-role Bearer
- [ ] No real secrets in git

## 2. Automated tests

- [ ] `xcodebuild test -project GrubShelf.xcodeproj -scheme GrubShelf -destination 'platform=iOS Simulator,name=iPhone 17'`
- [ ] All `GrubShelfTests` green (required for merge/release)

## 3. Backend

- [ ] Migrations through `073` applied on production
- [ ] Run [BACKEND_VERIFICATION.sql](BACKEND_VERIFICATION.sql) in SQL Editor
- [ ] Supabase security/performance advisors reviewed

## 4. Push (real device)

- [ ] Production APNs key in Supabase secrets
- [ ] Release build uses production `aps-environment` (not development-only)
- [ ] Device registers token; approval push delivers and tap routes correctly
- [ ] See [APNS_SETUP_GUIDE.md](APNS_SETUP_GUIDE.md)

## 5. App config

- [ ] `GrubShelf/Config.plist` on build machine (Supabase URL, anon key, Google client ID)
- [ ] `scripts/test_auth_session.sh` passes

## 6. Manual regression

- [ ] Execute [REGRESSION_TEST_PLAN.md](REGRESSION_TEST_PLAN.md)
- [ ] Record results in [REGRESSION_EXECUTION_LOG.md](REGRESSION_EXECUTION_LOG.md)

## 7. TestFlight

- [ ] Follow [TESTFLIGHT_BETA_GUIDE.md](TESTFLIGHT_BETA_GUIDE.md)
- [ ] 1–2 weeks household beta; triage blockers

## 8. App Store

- [ ] Marketing copy matches shipped features (no premium/recipes unless live)
- [ ] Version bumped in `project.yml`

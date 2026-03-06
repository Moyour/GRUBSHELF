# Apple Sign In Setup

For Sign in with Apple to work, the Apple provider must be enabled in your Supabase project.

## Supabase Hosted (Dashboard)

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Authentication** → **Providers**
2. Enable **Apple** (toggle ON)
3. Under **Client IDs**, add your app's Bundle ID: `com.foodpan.FoodPan`
4. For **native iOS only** (no web OAuth): You do **not** need Services ID, signing key, or secret. Leave those blank.

## Supabase Local (config.toml)

If using `supabase start` for local development, the Apple provider is enabled in `supabase/config.toml`:

- `[auth.external.apple]` → `enabled = true`
- `client_id = "com.foodpan.FoodPan"` (your Bundle ID)

Restart Supabase after changes: `supabase stop` then `supabase start`.

## Apple Developer Console

1. Ensure your App ID has **Sign in with Apple** enabled (Xcode → Signing & Capabilities)
2. The `FoodPan.entitlements` file already includes `com.apple.developer.applesignin`

## Troubleshooting

- **"appleid isn't enabled"** / **"Provider issuer not enabled"** / **400 error**: The Apple provider is disabled or not configured.
  - **Supabase Hosted**: Go to [Dashboard](https://supabase.com/dashboard) → your project → **Authentication** → **Providers** → find **Apple** → turn the toggle **ON**. Add `com.foodpan.FoodPan` under **Client IDs**.
  - **Supabase Local**: Ensure `supabase/config.toml` has `[auth.external.apple]` with `enabled = true` and `client_id = "com.foodpan.FoodPan"`. Then run `supabase stop` and `supabase start`.
- **Bundle ID not in Client IDs**: Add `com.foodpan.FoodPan` to the Client IDs list in Supabase.
- **OIDC issuer mismatch** (`expected https://appleid.apple.com got https://account.apple.com`): Apple changed their issuer URL in 2025. Supabase has fixed this—ensure your Supabase project is up to date. If using self-hosted, pull the latest Supabase Auth. Track [supabase/auth#2051](https://github.com/supabase/auth/issues/2051).
- **Native sign-in**: For `signInWithIdToken` (native iOS), you do **not** need Services ID, signing key, or secret. The secret in config is only for web OAuth. Leave it blank or unset for native-only.

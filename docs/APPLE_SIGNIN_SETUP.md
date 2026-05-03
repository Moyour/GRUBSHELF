# Apple Sign In Setup

For Sign in with Apple to work, the Apple provider must be enabled in your Supabase project.

## Supabase Hosted (Dashboard)

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Authentication** → **Providers**
2. Enable **Apple** (toggle ON)
3. Under **Client IDs**, add your app's Bundle ID: `com.grubshelf.GrubShelf`
4. For **native iOS only** (no web OAuth): You do **not** need Services ID, signing key, or secret. Leave those blank.

## Supabase Local (config.toml)

If using `supabase start` for local development, the Apple provider is enabled in `supabase/config.toml`:

- `[auth.external.apple]` → `enabled = true`
- `client_id = "com.grubshelf.GrubShelf"` (your Bundle ID)

Restart Supabase after changes: `supabase stop` then `supabase start`.

## Apple Developer Console

1. Ensure your App ID has **Sign in with Apple** enabled (Xcode → Signing & Capabilities)
2. The `GrubShelf.entitlements` file already includes `com.apple.developer.applesignin`

## Troubleshooting

- **"appleid isn't enabled"** / **"Provider issuer not enabled"** / **400 error**: The Apple provider is disabled or not configured.
  - **Supabase Hosted**: Go to [Dashboard](https://supabase.com/dashboard) → your project → **Authentication** → **Providers** → find **Apple** → turn the toggle **ON**. Add `com.grubshelf.GrubShelf` under **Client IDs**.
  - **Supabase Local**: Ensure `supabase/config.toml` has `[auth.external.apple]` with `enabled = true` and `client_id = "com.grubshelf.GrubShelf"`. Then run `supabase stop` and `supabase start`.
- **Bundle ID not in Client IDs**: Add `com.grubshelf.GrubShelf` to the Client IDs list in Supabase.
- **"Unacceptable audience in id_token: [com.grubshelf.GrubShelf]"** (or similar): The Apple **identity token** always has JWT claim `aud` = your **iOS bundle ID** for native `signInWithIdToken`. Supabase only accepts tokens whose `aud` is listed under the Apple provider’s **Client IDs**. Fix: In the Dashboard → **Authentication** → **Providers** → **Apple** → **Client IDs**, ensure `com.grubshelf.GrubShelf` is included. If you also use a **Services ID** for web Sign in with Apple, list **both** (comma-separated in one field where the dashboard allows multiple). If the field still has an old bundle ID (e.g. from a renamed app), replace it or add the current bundle ID. For **local** Supabase, set `client_id` under `[auth.external.apple]` to that bundle ID, or comma-separated `bundleId,servicesId` if you use both flows.
- **OIDC issuer mismatch** (`expected https://appleid.apple.com got https://account.apple.com`): Apple changed their issuer URL in 2025. Supabase has fixed this—ensure your Supabase project is up to date. If using self-hosted, pull the latest Supabase Auth. Track [supabase/auth#2051](https://github.com/supabase/auth/issues/2051).
- **"Passed nonce and nonce in id_token should either both exist or not"**: Supabase (GoTrue) rejects the request if you send a `nonce` in the API body but Apple’s JWT has no `nonce` claim (or the reverse). The app only sends `nonce` when the decoded identity token actually includes that claim, so native sign-in stays valid across simulator and device quirks.
- **Native sign-in**: For `signInWithIdToken` (native iOS), you do **not** need Services ID, signing key, or secret. The secret in config is only for web OAuth. Leave it blank or unset for native-only.

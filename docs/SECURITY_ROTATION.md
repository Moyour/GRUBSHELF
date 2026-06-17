# Security rotation checklist

## Service role key

If `VAULT_SECRETS_READY_TO_RUN.sql` or any doc ever contained a real `service_role` JWT in git:

1. Supabase Dashboard → **Settings → API** → rotate **service_role** key.
2. Update Vault secrets (`service_role_key`) or `push_config.service_role_key` in production SQL.
3. Redeploy edge functions: `send-daily-digest`, `send-push`, `send-household-invite`.
4. Re-run `[docs/CONFIGURE_VAULT_SECRETS.sql](CONFIGURE_VAULT_SECRETS.sql)` placeholders only in the SQL editor (never commit real keys).

## Edge function auth

- `send-daily-digest` and `send-push` require `Authorization: Bearer <service_role_key>` (see `supabase/functions/_shared/service_role_auth.ts`).
- `send-household-invite` requires a valid **user** session JWT (`verify_jwt = true`).

## Push credentials

Prefer **Supabase Vault** (`project_url`, `service_role_key`) for cron/trigger HTTP calls. The `push_config` table stores the service role in plaintext (RLS blocks API access; still rotate if DB backups leak).

## Never commit

- Real JWTs, APNs `.p8` keys, SMTP passwords, Resend API keys.
- Use `PASTE_YOUR_*` placeholders in SQL templates only.

#!/usr/bin/env bash
# Push auth settings and email templates from supabase/config.toml + supabase/templates/
# to the linked hosted project. Required for password-reset emails to use recovery.html.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! supabase projects list 2>/dev/null | grep -q '●'; then
  echo "No linked Supabase project. Run: supabase link --project-ref <your-ref>"
  exit 1
fi

echo "Pushing auth config and email templates (confirmation + recovery)..."
supabase config push --yes

echo "Done. Request a new password reset email to verify the template."

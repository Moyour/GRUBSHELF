import { createClient } from "@supabase/supabase-js";
import { requireServiceRole } from "../_shared/service_role_auth.ts";

/**
 * Expire-subscriptions Edge Function.
 *
 * Calls the `expire_subscriptions()` RPC (migration 077) which downgrades
 * any premium subscription past its current_period_end back to the free plan.
 *
 * Intended to be triggered by:
 *  - pg_cron (if available on the Supabase plan)
 *  - An external cron service (e.g. cron-job.org, GitHub Actions) as a fallback
 *
 * Requires service-role authorization.
 */

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authFailure = requireServiceRole(req, json);
  if (authFailure) return authFailure;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return json({ error: "Server misconfigured" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  try {
    const { error } = await supabase.rpc("expire_subscriptions");
    if (error) {
      console.error("expire_subscriptions RPC failed:", error.message);
      return json({ ok: false, error: error.message }, 500);
    }

    console.log("expire_subscriptions completed successfully");
    return json({ ok: true }, 200);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Unexpected error:", message);
    return json({ ok: false, error: message }, 500);
  }
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

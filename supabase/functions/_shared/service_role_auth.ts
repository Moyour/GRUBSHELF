/**
 * Restricts edge function access to callers presenting the service-role key
 * (e.g. pg_cron / database triggers). User JWTs must not pass.
 */
export function requireServiceRole(
  req: Request,
  json: (body: unknown, status?: number) => Response,
): Response | null {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "Missing authorization" }, 401);
  }

  const token = authHeader.slice("Bearer ".length).trim();
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceRoleKey || token !== serviceRoleKey) {
    return json({ error: "Unauthorized" }, 401);
  }

  return null;
}

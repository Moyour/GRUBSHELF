import { createClient } from "npm:@supabase/supabase-js@2";

type HouseholdInviteRow = {
  invite_id: string;
  household_id: string;
  invited_email: string;
  invited_by: string;
  status: string;
  expires_at: string;
  households: { name: string } | null;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
    return json({ error: "Server misconfigured" }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: authError } = await supabase.auth.getUser();
  if (authError || !userData.user) {
    return json({ error: "Invalid session" }, 401);
  }
  const userId = userData.user.id;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const inviteId =
    typeof body === "object" && body !== null && "invite_id" in body
      ? (body as { invite_id: unknown }).invite_id
      : undefined;

  if (typeof inviteId !== "string" || inviteId.length === 0) {
    return json({ error: "invite_id required" }, 400);
  }

  const { data: invite, error: inviteError } = await supabase
    .from("household_invites")
    .select("invite_id, household_id, invited_email, invited_by, status, expires_at, households(name)")
    .eq("invite_id", inviteId)
    .single();

  if (inviteError || !invite) {
    return json({ error: "Invite not found" }, 404);
  }

  const row = invite as HouseholdInviteRow;

  if (row.status !== "pending") {
    return json({ error: "Invite not active" }, 400);
  }

  if (new Date(row.expires_at) < new Date()) {
    return json({ error: "Invite expired" }, 400);
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("household_id, role")
    .eq("user_id", userId)
    .single();

  if (profileError || !profile) {
    return json({ error: "Forbidden" }, 403);
  }

  if (profile.household_id !== row.household_id || profile.role !== "admin") {
    return json({ error: "Forbidden" }, 403);
  }

  const householdName = row.households?.name ?? "your household";

  const { data: inviter } = await supabase
    .from("users")
    .select("name")
    .eq("user_id", row.invited_by)
    .single();

  const inviterName = inviter?.name ?? "A household admin";

  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) {
    console.error("RESEND_API_KEY not set");
    return json({ error: "Email not configured" }, 503);
  }

  const from =
    Deno.env.get("HOUSEHOLD_INVITE_EMAIL_FROM") ??
    "GrubShelf <onboarding@resend.dev>";

  const subject = `You're invited to join ${householdName} on GrubShelf`;
  const html = `<p>Hi,</p>
<p><strong>${escapeHtml(inviterName)}</strong> invited you to join <strong>${escapeHtml(householdName)}</strong> on GrubShelf.</p>
<p>Open the GrubShelf app and sign in or sign up with <strong>${escapeHtml(row.invited_email)}</strong> to see and accept the invite.</p>
<p>If you did not expect this message, you can ignore this email.</p>`;

  const resendRes = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [row.invited_email],
      subject,
      html,
    }),
  });

  if (!resendRes.ok) {
    const detail = await resendRes.text();
    console.error("Resend failed", resendRes.status, detail);
    return json({ error: "Failed to send email" }, 502);
  }

  return json({ ok: true }, 200);
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildHouseholdInviteEmailContent,
  buildHouseholdInvitePlainText,
  sendInviteViaResend,
} from "./invite_email.ts";

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
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    console.error("Missing SUPABASE_URL, SUPABASE_ANON_KEY, or SUPABASE_SERVICE_ROLE_KEY");
    return json({ error: "Server misconfigured" }, 500);
  }

  // User-scoped client for auth verification only
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: authError } = await userClient.auth.getUser();
  if (authError || !userData.user) {
    return json({ error: "Invalid session" }, 401);
  }
  const userId = userData.user.id;

  // Service-role client for data queries (bypasses RLS)
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

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
    .select(
      "invite_id, household_id, invited_email, invited_by, status, expires_at, households(name)",
    )
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

  const { subject, html } = buildHouseholdInviteEmailContent({
    householdName,
    inviterName,
    invitedEmail: row.invited_email,
    inviteId: row.invite_id,
  });

  const plainText = buildHouseholdInvitePlainText({
    householdName,
    inviterName,
    invitedEmail: row.invited_email,
    inviteId: row.invite_id,
  });

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const resendFrom =
    Deno.env.get("HOUSEHOLD_INVITE_EMAIL_FROM") ??
    "GrubShelf <onboarding@resend.dev>";

  if (resendKey) {
    const sent = await sendInviteViaResend({
      apiKey: resendKey,
      from: resendFrom,
      to: row.invited_email,
      subject,
      html,
      text: plainText,
    });
    if (!sent.ok) {
      console.error("Resend send failed:", sent.status, sent.body);
      return json({ error: "Failed to send email" }, 502);
    }
    const inviteEmailSender = /\bonboarding@resend\.dev\b/i.test(resendFrom)
      ? "resend_onboarding"
      : "resend";
    return json({ ok: true, invite_email_sender: inviteEmailSender }, 200);
  }

  const smtpHost = Deno.env.get("SMTP_HOST");
  const smtpPort = parseInt(Deno.env.get("SMTP_PORT") ?? "587", 10);
  const smtpUser = Deno.env.get("SMTP_USER");
  const smtpPass = Deno.env.get("SMTP_PASS");

  if (!smtpHost || !smtpUser || !smtpPass) {
    console.error(
      "Email not configured: set RESEND_API_KEY (and optionally HOUSEHOLD_INVITE_EMAIL_FROM), or SMTP_HOST, SMTP_USER, SMTP_PASS",
    );
    return json(
      {
        error: "Email not configured",
        hint:
          "Set secret RESEND_API_KEY (recommended) and HOUSEHOLD_INVITE_EMAIL_FROM, or SMTP_HOST, SMTP_USER, SMTP_PASS on the send-household-invite function.",
      },
      503,
    );
  }

  const { SMTPClient } = await import("denomailer");
  const smtp = new SMTPClient({
    connection: {
      hostname: smtpHost,
      port: smtpPort,
      tls: true,
      auth: { username: smtpUser, password: smtpPass },
    },
  });

  try {
    await smtp.connect();
    await smtp.send({
      from: smtpUser,
      to: row.invited_email,
      subject,
      html,
    });
  } catch (err) {
    console.error("SMTP send failed:", err);
    return json({ error: "Failed to send email" }, 502);
  } finally {
    await smtp.close();
  }

  return json({ ok: true, invite_email_sender: "smtp" }, 200);
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

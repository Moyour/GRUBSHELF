import { createClient } from "@supabase/supabase-js";

/**
 * Daily digest Edge Function — triggered by pg_cron.
 *
 * Sends one email per user summarising:
 *  - Pantry items expiring within 3 days
 *  - Items below low-stock threshold
 *  - Budget status (if a budget is configured)
 *
 * Requires RESEND_API_KEY and uses the service role key
 * (set automatically for cron-invoked functions).
 */

type PantryRow = {
  item_id: string;
  name: string;
  expiry_date: string | null;
  quantity: number;
  low_stock_threshold: number;
};

type UserRow = {
  user_id: string;
  email: string;
  name: string;
  household_id: string | null;
};

type FinanceRow = {
  budget_amount_minor: number;
  budget_period: string;
};

type TripRow = {
  total_cost_minor: number | null;
};

Deno.serve(async (req) => {
  // Only allow POST (cron trigger sends POST)
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendKey = Deno.env.get("RESEND_API_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return json({ error: "Server misconfigured" }, 500);
  }
  if (!resendKey) {
    console.error("RESEND_API_KEY not set");
    return json({ error: "Email not configured" }, 503);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Fetch users who opted in to email notifications and belong to a household
  const { data: users, error: usersErr } = await supabase
    .from("users")
    .select("user_id, email, name, household_id")
    .eq("email_notifications_enabled", true)
    .not("household_id", "is", null);

  if (usersErr) {
    console.error("Failed to fetch users:", usersErr.message);
    return json({ error: "Failed to fetch users" }, 500);
  }

  const from =
    Deno.env.get("DIGEST_EMAIL_FROM") ??
    "GrubShelf <onboarding@resend.dev>";

  let sent = 0;
  let skipped = 0;

  for (const user of (users as UserRow[]) ?? []) {
    if (!user.household_id || !user.email) {
      skipped++;
      continue;
    }

    try {
      const sections = await buildDigestSections(
        supabase,
        user.household_id,
        user.user_id
      );

      if (sections.length === 0) {
        skipped++;
        continue; // Nothing to report
      }

      const html = renderDigestEmail(user.name, sections);

      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from,
          to: [user.email],
          subject: "Your GrubShelf daily digest",
          html,
        }),
      });

      if (!res.ok) {
        const detail = await res.text();
        console.error(
          `Resend failed for ${user.email}: ${res.status} ${detail}`
        );
      } else {
        sent++;
      }
    } catch (err) {
      console.error(`Error processing user ${user.user_id}:`, err);
    }
  }

  console.log(`Daily digest complete: sent=${sent}, skipped=${skipped}`);
  return json({ ok: true, sent, skipped }, 200);
});

// ---------------------------------------------------------------------------

type DigestSection = {
  title: string;
  icon: string;
  items: string[];
};

async function buildDigestSections(
  supabase: ReturnType<typeof createClient>,
  householdId: string,
  userId: string
): Promise<DigestSection[]> {
  const sections: DigestSection[] = [];
  const now = new Date();
  const threeDaysOut = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const threeDaysISO = threeDaysOut.toISOString().split("T")[0];

  // 1. Expiring items (within 3 days)
  const { data: expiring } = await supabase
    .from("pantry_items")
    .select("item_id, name, expiry_date, quantity, low_stock_threshold")
    .eq("household_id", householdId)
    .eq("is_archived", false)
    .not("expiry_date", "is", null)
    .lte("expiry_date", threeDaysISO)
    .gte("expiry_date", now.toISOString().split("T")[0])
    .order("expiry_date", { ascending: true })
    .limit(20);

  if (expiring && expiring.length > 0) {
    sections.push({
      title: "Expiring soon",
      icon: "\u23F3", // hourglass
      items: (expiring as PantryRow[]).map((item) => {
        const daysLeft = Math.ceil(
          (new Date(item.expiry_date!).getTime() - now.getTime()) /
            (24 * 60 * 60 * 1000)
        );
        const label =
          daysLeft <= 0
            ? "today"
            : daysLeft === 1
            ? "tomorrow"
            : `in ${daysLeft} days`;
        return `${esc(item.name)} — expires ${label}`;
      }),
    });
  }

  // 2. Low stock items
  const { data: lowStock } = await supabase
    .from("pantry_items")
    .select("item_id, name, expiry_date, quantity, low_stock_threshold")
    .eq("household_id", householdId)
    .eq("is_archived", false)
    .gt("low_stock_threshold", 0)
    .limit(100);

  if (lowStock) {
    const belowThreshold = (lowStock as PantryRow[]).filter(
      (item) => item.quantity <= item.low_stock_threshold
    );
    if (belowThreshold.length > 0) {
      sections.push({
        title: "Low stock",
        icon: "\uD83D\uDCE6", // package
        items: belowThreshold.slice(0, 15).map((item) => {
          return `${esc(item.name)} — ${item.quantity} left (threshold: ${item.low_stock_threshold})`;
        }),
      });
    }
  }

  // 3. Budget status
  const { data: finSettings } = await supabase
    .from("finance_settings")
    .select("budget_amount_minor, budget_period")
    .eq("user_id", userId)
    .single();

  if (finSettings) {
    const settings = finSettings as FinanceRow;
    if (settings.budget_amount_minor > 0) {
      const period = computePeriod(now, settings.budget_period);
      const { data: trips } = await supabase
        .from("shopping_trips")
        .select("total_cost_minor")
        .eq("household_id", householdId)
        .eq("period", period);

      const spent = (trips as TripRow[] | null)
        ?.map((t) => t.total_cost_minor ?? 0)
        .reduce((a, b) => a + b, 0) ?? 0;

      const budget = settings.budget_amount_minor;
      const pct = Math.round((spent / budget) * 100);

      if (pct >= 75) {
        const spentStr = formatMinor(spent);
        const budgetStr = formatMinor(budget);
        sections.push({
          title: "Budget alert",
          icon: "\uD83D\uDCB0", // money bag
          items: [
            `You've spent ${spentStr} of your ${budgetStr} ${settings.budget_period} budget (${pct}%).`,
          ],
        });
      }
    }
  }

  return sections;
}

function computePeriod(date: Date, budgetPeriod: string): string {
  if (budgetPeriod === "weekly") {
    // ISO week calculation
    const d = new Date(
      Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
    );
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    const weekNo = Math.ceil(
      ((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7
    );
    return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
  }
  // monthly
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

function formatMinor(amountMinor: number): string {
  return `$${(amountMinor / 100).toFixed(2)}`;
}

function renderDigestEmail(
  userName: string,
  sections: DigestSection[]
): string {
  const sectionHtml = sections
    .map(
      (s) => `
      <tr>
        <td style="padding: 16px 28px 8px 28px">
          <p style="margin: 0; font-size: 16px; font-weight: 600; color: #27272a">${s.icon} ${esc(s.title)}</p>
        </td>
      </tr>
      <tr>
        <td style="padding: 0 28px 12px 28px">
          <ul style="margin: 8px 0 0 0; padding-left: 20px; font-size: 14px; line-height: 1.8; color: #3f3f46">
            ${s.items.map((i) => `<li>${i}</li>`).join("\n            ")}
          </ul>
        </td>
      </tr>`
    )
    .join("");

  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>Daily Digest</title></head>
<body style="margin:0;padding:0;background-color:#f4f4f5;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f4f5;padding:32px 16px">
<tr><td align="center">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.08)">
  <tr><td style="padding:28px 28px 8px"><p style="margin:0;font-size:15px;font-weight:600;color:#27272a">GrubShelf</p></td></tr>
  <tr><td style="padding:8px 28px"><h1 style="margin:0;font-size:22px;line-height:1.3;font-weight:600">Daily Digest</h1></td></tr>
  <tr><td style="padding:4px 28px 12px"><p style="margin:0;font-size:15px;color:#3f3f46">Hi ${esc(userName)}, here's what needs your attention today.</p></td></tr>
  ${sectionHtml}
  <tr><td style="padding:16px 28px 28px;border-top:1px solid #e4e4e7"><p style="margin:0;font-size:13px;color:#71717a">Open the GrubShelf app to take action. You can disable these emails in Settings.</p></td></tr>
</table>
<p style="margin:20px 0 0;font-size:12px;color:#a1a1aa;max-width:480px">You received this because email notifications are enabled in your GrubShelf settings.</p>
</td></tr>
</table>
</body></html>`;
}

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function esc(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

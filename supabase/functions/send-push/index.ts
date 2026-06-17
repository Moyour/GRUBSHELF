import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { createClient } from "@supabase/supabase-js";
import { requireServiceRole } from "../_shared/service_role_auth.ts";

type PushRequest = {
  user_id: string;
  title: string;
  body: string;
  category?: string;
  data?: Record<string, unknown>;
};

type DeviceTokenRow = {
  token: string;
  platform: string;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authFailure = requireServiceRole(req, json);
  if (authFailure) return authFailure;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apnsKeyId = Deno.env.get("APNS_KEY_ID");
  const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
  const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID");
  const apnsUseSandbox = Deno.env.get("APNS_USE_SANDBOX") === "true";

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Server misconfigured" }, 500);
  }

  if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey || !apnsBundleId) {
    return json({ skipped: true, reason: "APNs not configured" }, 202);
  }

  let payload: PushRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  if (!payload.user_id || !payload.title || !payload.body) {
    return json({ error: "Missing user_id, title, or body" }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data: tokens, error } = await supabase
    .from("push_device_tokens")
    .select("token, platform")
    .eq("user_id", payload.user_id);

  if (error) {
    console.error("Failed to load push tokens:", error.message);
    return json({ error: "Failed to load tokens" }, 500);
  }

  const rows = (tokens as DeviceTokenRow[]) ?? [];
  if (rows.length === 0) {
    return json({ sent: 0, skipped: true, reason: "No device tokens" }, 202);
  }

  const jwt = await createApnsJwt(apnsKeyId, apnsTeamId, apnsPrivateKey);
  const host = apnsUseSandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  let sent = 0;
  let failed = 0;

  for (const row of rows) {
    if (row.platform !== "ios") continue;

    const response = await fetch(`${host}/3/device/${row.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": apnsBundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        aps: {
          alert: {
            title: payload.title,
            body: payload.body,
          },
          sound: "default",
          category: payload.category ?? "GENERAL",
        },
        data: payload.data ?? {},
        destination: destinationForCategory(payload.category, payload.data),
      }),
    });

    if (response.ok) {
      sent += 1;
    } else {
      failed += 1;
      const reason = await response.text();
      console.error("APNs delivery failed:", response.status, reason);
    }
  }

  return json({ sent, failed });
});

async function createApnsJwt(
  keyId: string,
  teamId: string,
  privateKeyPem: string,
): Promise<string> {
  const normalizedKey = privateKeyPem.replace(/\\n/g, "\n");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(normalizedKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  return await create(
    { alg: "ES256", kid: keyId },
    { iss: teamId, iat: getNumericDate(0) },
    key,
  );
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const raw = atob(base64);
  const buffer = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i += 1) {
    buffer[i] = raw.charCodeAt(i);
  }
  return buffer.buffer;
}

function destinationForCategory(
  category: string | undefined,
  data: Record<string, unknown> | undefined,
): string | undefined {
  if (category === "item_pending_approval") return "approvals";
  if (category === "item_approved") {
    return data?.item_type === "shopping" ? "shop" : "pantry_expiring";
  }
  if (category === "item_rejected") {
    return data?.item_type === "shopping" ? "shop" : "pantry_expiring";
  }
  if (data?.item_type === "shopping") return "shop";
  return undefined;
}

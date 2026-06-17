import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requireServiceRole } from "./service_role_auth.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.test("requireServiceRole rejects missing Authorization", () => {
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  const req = new Request("https://example.com", { method: "POST" });
  const res = requireServiceRole(req, json);
  assertEquals(res?.status, 401);
});

Deno.test("requireServiceRole rejects wrong bearer", () => {
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  const req = new Request("https://example.com", {
    method: "POST",
    headers: { Authorization: "Bearer user-jwt" },
  });
  const res = requireServiceRole(req, json);
  assertEquals(res?.status, 401);
});

Deno.test("requireServiceRole accepts service role bearer", () => {
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  const req = new Request("https://example.com", {
    method: "POST",
    headers: { Authorization: "Bearer test-service-key" },
  });
  const res = requireServiceRole(req, json);
  assertEquals(res, null);
});

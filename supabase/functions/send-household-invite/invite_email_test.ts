import {
  buildHouseholdInviteEmailContent,
  buildHouseholdInvitePlainText,
  escapeHtml,
} from "./invite_email.ts";

Deno.test("escapeHtml escapes special characters", () => {
  const got = escapeHtml(`a & b < c > "x"`);
  const want = "a &amp; b &lt; c &gt; &quot;x&quot;";
  if (got !== want) throw new Error(`expected ${want}, got ${got}`);
});

Deno.test("buildHouseholdInviteEmailContent builds subject and html", () => {
  const { subject, html } = buildHouseholdInviteEmailContent({
    householdName: "The Pantry",
    inviterName: "Sam",
    invitedEmail: "friend@example.com",
    inviteId: "123e4567-e89b-12d3-a456-426614174000",
  });
  if (subject !== "You're invited to join The Pantry on GrubShelf") {
    throw new Error("bad subject");
  }
  if (!html.includes("Sam") || !html.includes("The Pantry")) {
    throw new Error("html missing expected content");
  }
  if (!html.includes("grubshelf://invite?token=123e4567-e89b-12d3-a456-426614174000")) {
    throw new Error("html missing invite deep link");
  }
});

Deno.test("buildHouseholdInviteEmailContent escapes XSS-ish names", () => {
  const { html } = buildHouseholdInviteEmailContent({
    householdName: "<script>",
    inviterName: "& Co",
    invitedEmail: "a@b.com",
    inviteId: "123e4567-e89b-12d3-a456-426614174000",
  });
  if (html.includes("<script>")) throw new Error("raw script leaked");
  if (!html.includes("&lt;script&gt;")) throw new Error("expected escaped script");
  if (!html.includes("&amp; Co")) throw new Error("expected escaped ampersand");
});

Deno.test("buildHouseholdInvitePlainText matches readable body", () => {
  const text = buildHouseholdInvitePlainText({
    householdName: "The Pantry",
    inviterName: "Sam",
    invitedEmail: "friend@example.com",
    inviteId: "123e4567-e89b-12d3-a456-426614174000",
  });
  if (!text.includes("Sam")) throw new Error("missing inviter");
  if (!text.includes("The Pantry")) throw new Error("missing household");
  if (!text.includes("grubshelf://invite?token=123e4567-e89b-12d3-a456-426614174000")) {
    throw new Error("missing invite deep link");
  }
  if (text.includes("<")) throw new Error("unexpected html");
});

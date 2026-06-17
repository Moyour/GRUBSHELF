/** Pure helpers for household invite emails (used by Edge Function + tests). */

export function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function buildHouseholdInviteEmailContent(input: {
  householdName: string;
  inviterName: string;
  invitedEmail: string;
  inviteId: string;
}): { subject: string; html: string } {
  const { householdName, inviterName, invitedEmail, inviteId } = input;
  const subject = `You're invited to join ${householdName} on GrubShelf`;
  const safeInviter = escapeHtml(inviterName);
  const safeHousehold = escapeHtml(householdName);
  const safeEmail = escapeHtml(invitedEmail);
  const inviteLink = `grubshelf://invite?token=${inviteId}`;
  const testFlightLink = `https://testflight.apple.com/join/8M8EJsUE`;
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>You're Invited — GrubShelf</title>
</head>
<body style="margin:0;padding:0;background-color:#E8E4DC;font-family:'DM Sans',Arial,Helvetica,sans-serif;-webkit-font-smoothing:antialiased;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#E8E4DC;padding:40px 16px;">
<tr><td align="center">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;background-color:#FFFDF9;border-radius:16px;overflow:hidden;">

  <!-- Header -->
  <tr>
    <td style="background-color:#085041;padding:32px 40px;text-align:center;">
      <span style="font-size:28px;font-weight:700;letter-spacing:-0.5px;color:#FFFFFF;">grub</span><span style="font-size:28px;font-weight:700;letter-spacing:-0.5px;color:#FFFFFF;text-decoration:underline;text-decoration-color:#E8A020;text-underline-offset:4px;text-decoration-thickness:3px;">shelf</span>
    </td>
  </tr>

  <!-- Icon & Heading -->
  <tr>
    <td style="padding:40px 40px 0;text-align:center;">
      <div style="width:64px;height:64px;border-radius:50%;background-color:rgba(232,160,32,0.12);margin:0 auto 20px;line-height:64px;font-size:28px;">🏠</div>
      <h1 style="margin:0;font-size:24px;font-weight:700;color:#085041;letter-spacing:-0.3px;">You've been invited!</h1>
    </td>
  </tr>

  <!-- Body -->
  <tr>
    <td style="padding:20px 40px 0;text-align:center;">
      <p style="margin:0;font-size:15px;line-height:1.7;color:#5A5A5A;"><strong>${safeInviter}</strong> has invited you to join <strong>${safeHousehold}</strong> on GrubShelf — the app that helps households track their pantry, shopping lists, and grocery budget all in one place.</p>
    </td>
  </tr>

  <!-- Instructions -->
  <tr>
    <td style="padding:20px 40px 0;text-align:left;">
      <div style="background-color:#F5F5F5;border-left:4px solid #E8A020;padding:16px 20px;border-radius:8px;">
        <p style="margin:0;font-size:14px;line-height:1.6;color:#5A5A5A;font-weight:600;">To accept this invitation:</p>
        <ol style="margin:12px 0 0 0;padding-left:20px;font-size:14px;line-height:1.8;color:#5A5A5A;">
          <li>Download GrubShelf from TestFlight (button below)</li>
          <li>Sign up or sign in with <strong>${safeEmail}</strong></li>
          <li>Accept the invitation when prompted</li>
        </ol>
      </div>
    </td>
  </tr>

  <!-- CTA Button -->
  <tr>
    <td style="padding:28px 40px;text-align:center;">
      <a href="${testFlightLink}" target="_blank" style="display:inline-block;background-color:#E8A020;color:#085041;font-family:'DM Sans',Arial,sans-serif;font-size:15px;font-weight:700;text-decoration:none;padding:14px 40px;border-radius:8px;letter-spacing:0.3px;">Download GrubShelf →</a>
    </td>
  </tr>

  <!-- Alternative for existing users -->
  <tr>
    <td style="padding:0 40px 32px;text-align:center;">
      <p style="margin:0;font-size:13px;line-height:1.6;color:#999999;">Already have GrubShelf?</p>
      <p style="margin:8px 0 0;font-size:13px;line-height:1.6;color:#5A5A5A;">Just open the app and sign in with <strong>${safeEmail}</strong> to see your invitation.</p>
    </td>
  </tr>

  <!-- Divider -->
  <tr><td style="padding:0 40px;"><div style="height:1px;background-color:#E8E4DC;"></div></td></tr>

  <!-- Footer -->
  <tr>
    <td style="padding:24px 40px 32px;text-align:center;">
      <p style="margin:0;font-size:12px;line-height:1.6;color:#999999;">If you weren't expecting this invitation, you can safely ignore this email.</p>
      <p style="margin:12px 0 0;font-size:12px;color:#CCCCCC;">\u00A9 2026 GrubShelf. All rights reserved.</p>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>`;
  return { subject, html };
}

export function buildHouseholdInvitePlainText(input: {
  householdName: string;
  inviterName: string;
  invitedEmail: string;
  inviteId: string;
}): string {
  const testFlightLink = `https://testflight.apple.com/join/8M8EJsUE`;
  
  return [
    "You've been invited!",
    "",
    `${input.inviterName} has invited you to join ${input.householdName} on GrubShelf — the app that helps households track their pantry, shopping lists, and grocery budget all in one place.`,
    "",
    "To accept this invitation:",
    "1. Download GrubShelf from TestFlight",
    "2. Sign up or sign in with " + input.invitedEmail,
    "3. Accept the invitation when prompted",
    "",
    `Download GrubShelf: ${testFlightLink}`,
    "",
    "Already have GrubShelf?",
    `Just open the app and sign in with ${input.invitedEmail} to see your invitation.`,
    "",
    "If you weren't expecting this invitation, you can safely ignore this email.",
    "",
    "\u00A9 2026 GrubShelf. All rights reserved.",
  ].join("\n");
}

export async function sendInviteViaResend(input: {
  apiKey: string;
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
}): Promise<{ ok: true } | { ok: false; status: number; body: string }> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${input.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: input.from,
      to: [input.to],
      subject: input.subject,
      html: input.html,
      text: input.text,
    }),
  });

  if (!res.ok) {
    return { ok: false, status: res.status, body: await res.text() };
  }
  return { ok: true };
}

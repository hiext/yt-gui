/**
 * Transactional license-delivery email via Resend.
 *
 * Used by the P2 auto-issuance flow (payment/email webhook → issue code → email it).
 * The Resend API key is read from `env.RESEND_API_KEY`, which MUST be set as a
 * Worker secret (`wrangler secret put RESEND_API_KEY`) — never hardcode it.
 *
 * Resend free tier: 3,000 emails/month, 100/day. See EMAIL.md for the full design.
 */

const RESEND_ENDPOINT = 'https://api.resend.com/emails';

export type Tier = 'pro' | 'team';

export interface EmailEnv {
  /** Resend API key — injected as a Worker secret, never committed. */
  RESEND_API_KEY: string;
  /** Optional verified sender, e.g. "HiExt <license@hiext.com>". Falls back to a default. */
  LICENSE_FROM_EMAIL?: string;
}

export interface SendResult {
  ok: boolean;
  id?: string;
  error?: string;
}

const TIER_LABEL: Record<Tier, string> = {
  pro: '专业版 Pro',
  team: '团队版 Team',
};

const TIER_DEVICES: Record<Tier, number> = {
  pro: 3,
  team: 10,
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderHtml(code: string, tier: Tier): string {
  const label = TIER_LABEL[tier];
  const devices = TIER_DEVICES[tier];
  const safeCode = escapeHtml(code);
  return `<!DOCTYPE html>
<html lang="zh-CN">
  <body style="margin:0;background:#eef4ff;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#0f172a;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="520" cellpadding="0" cellspacing="0"
                 style="max-width:520px;background:#ffffff;border-radius:20px;padding:36px;box-shadow:0 16px 40px rgba(15,23,42,0.08);">
            <tr><td>
              <h1 style="margin:0 0 8px;font-size:22px;">感谢购买 HiExt YT GUI ${label}</h1>
              <p style="margin:0 0 24px;color:#52607a;line-height:1.7;">
                以下是你的激活码。请在桌面 App 内「设置 · 激活」处输入并联网激活，可绑定最多 ${devices} 台设备。
              </p>
              <div style="padding:18px 20px;border:1px solid rgba(49,86,197,0.26);border-radius:14px;background:#f8fbff;
                          font-family:'Space Grotesk',monospace;font-size:20px;letter-spacing:0.04em;text-align:center;">
                ${safeCode}
              </div>
              <p style="margin:24px 0 0;color:#b45309;font-weight:600;line-height:1.6;">
                请妥善保存本邮件：激活码仅通过此邮件发送一次。
              </p>
              <p style="margin:20px 0 0;color:#52607a;font-size:13px;line-height:1.7;">
                遇到激活问题？回复本邮件或在 GitHub 仓库提交 Issue，我们会尽快协助。<br />© 2026 HiExt
              </p>
            </td></tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function renderText(code: string, tier: Tier): string {
  const label = TIER_LABEL[tier];
  const devices = TIER_DEVICES[tier];
  return [
    `感谢购买 HiExt YT GUI ${label}。`,
    '',
    `你的激活码：${code}`,
    '',
    `请在桌面 App「设置 · 激活」处输入并联网激活，可绑定最多 ${devices} 台设备。`,
    '激活码仅通过本邮件发送一次，请妥善保存。',
    '',
    '© 2026 HiExt',
  ].join('\n');
}

/**
 * Send a license activation code to a buyer via Resend.
 *
 * @param env  Worker env providing `RESEND_API_KEY` (secret) and optional `LICENSE_FROM_EMAIL`.
 * @param to   Recipient email address.
 * @param code Plaintext activation code (only ever emailed once, never persisted in plaintext).
 * @param tier License tier — controls copy and device-count wording.
 * @returns    `{ ok, id }` on success, `{ ok: false, error }` on failure. Never throws on API errors.
 */
export async function sendLicenseEmail(
  env: EmailEnv,
  to: string,
  code: string,
  tier: Tier,
): Promise<SendResult> {
  if (!env.RESEND_API_KEY) {
    return { ok: false, error: 'RESEND_API_KEY not configured' };
  }
  if (!to) {
    return { ok: false, error: 'missing recipient' };
  }

  const from = env.LICENSE_FROM_EMAIL ?? 'HiExt <license@hiext.com>';
  const subject = `你的 HiExt YT GUI ${TIER_LABEL[tier]} 激活码`;

  try {
    const res = await fetch(RESEND_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject,
        html: renderHtml(code, tier),
        text: renderText(code, tier),
      }),
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      return { ok: false, error: `resend ${res.status}: ${detail.slice(0, 200)}` };
    }

    const data = (await res.json().catch(() => ({}))) as { id?: string };
    return { ok: true, id: data.id };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'unknown error';
    return { ok: false, error: message };
  }
}

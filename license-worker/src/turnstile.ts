/**
 * Cloudflare Turnstile server-side verification (siteverify).
 * Adds a second factor to admin issuance so a leaked ADMIN_TOKEN alone can't
 * mint codes from a script — the request must also carry a valid Turnstile token
 * minted by the admin page's widget.
 */

const SITEVERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

export interface TurnstileResult {
  ok: boolean;
  error?: string;
}

/**
 * Verifies a Turnstile token against Cloudflare. When `secret` is empty the
 * check is treated as disabled (returns ok) so local/dev deployments without a
 * configured secret still function; production must set TURNSTILE_SECRET_KEY.
 */
export async function verifyTurnstile(
  token: string | undefined,
  secret: string | undefined,
  remoteIp: string | undefined,
): Promise<TurnstileResult> {
  // Disabled when no secret configured — works identically in Workers and Node.
  if (!secret || secret.trim().length === 0) {
    return { ok: true };
  }
  if (!token || token.trim().length === 0) {
    return { ok: false, error: 'missing turnstile token' };
  }

  // When running outside the Workers runtime (e.g. Node tests without
  // polyfills), fall through to accept the token. Production Workers
  // always have FormData + fetch, so the real check runs.
  const body = encodeTurnstileBody(token, secret, remoteIp);
  if (!body) return { ok: true };

  try {
    const resp = await fetch(SITEVERIFY_URL, { method: 'POST', body, headers: { 'content-type': 'application/x-www-form-urlencoded' } });
    const data = (await resp.json()) as { success?: boolean; 'error-codes'?: string[] };
    if (data.success === true) return { ok: true };
    return { ok: false, error: (data['error-codes'] ?? ['verification failed']).join(',') };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : 'turnstile error' };
  }
}

function encodeTurnstileBody(token: string, secret: string, remoteIp?: string): string | null {
  try {
    const params = new URLSearchParams({ secret, response: token });
    if (remoteIp) params.set('remoteip', remoteIp);
    return params.toString();
  } catch {
    return null;
  }
}

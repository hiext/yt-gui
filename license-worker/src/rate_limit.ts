/**
 * Sliding-window rate limiting backed by Workers KV.
 * Mirrors the counting approach used by functions/api/waitlist.js.
 */

export interface RateLimitBinding {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
}

/**
 * Increments a per-key counter with a fixed TTL window.
 * Returns allowed=false once the count exceeds `limit` within `windowSeconds`.
 */
export async function checkRateLimit(
  kv: RateLimitBinding,
  key: string,
  limit: number,
  windowSeconds: number,
): Promise<RateLimitResult> {
  const stored = await kv.get(key);
  const current = stored ? Number.parseInt(stored, 10) || 0 : 0;

  if (current >= limit) {
    return { allowed: false, remaining: 0 };
  }

  await kv.put(key, String(current + 1), { expirationTtl: windowSeconds });
  return { allowed: true, remaining: limit - current - 1 };
}

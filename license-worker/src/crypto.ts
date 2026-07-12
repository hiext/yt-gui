/**
 * Ed25519 entitlement-token signing and license-code hashing.
 * Uses the Web Crypto API available in Cloudflare Workers.
 */

const encoder = new TextEncoder();

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function importSigningKey(base64Pkcs8: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'pkcs8',
    base64ToBytes(base64Pkcs8),
    { name: 'Ed25519' },
    false,
    ['sign'],
  );
}

export interface EntitlementClaims {
  tier: 'pro' | 'team';
  fingerprint: string;
  licenseId: string;
  iat: number;
  exp: number;
}

/**
 * Produce a compact signed token: base64url(header).base64url(payload).base64url(sig)
 * The app embeds the matching Ed25519 public key and verifies offline.
 */
export async function signEntitlementToken(
  claims: EntitlementClaims,
  privateKeyBase64: string,
): Promise<string> {
  const header = bytesToBase64Url(encoder.encode(JSON.stringify({ alg: 'Ed25519', typ: 'HIEXT-LIC' })));
  const payload = bytesToBase64Url(encoder.encode(JSON.stringify(claims)));
  const signingInput = `${header}.${payload}`;
  const key = await importSigningKey(privateKeyBase64);
  const signature = await crypto.subtle.sign('Ed25519', key, encoder.encode(signingInput));
  return `${signingInput}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

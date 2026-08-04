/**
 * License code generation and format validation.
 * Format: HIEXT-XXXXX-XXXXX-XXXXX-XXXXX (Crockford Base32, ambiguous chars removed).
 */

// Crockford Base32 alphabet without I, L, O, U to avoid confusion.
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const GROUP_LENGTH = 5;
const GROUP_COUNT = 4;
const encoder = new TextEncoder();

function randomGroup(): string {
  const bytes = new Uint8Array(GROUP_LENGTH);
  crypto.getRandomValues(bytes);
  let group = '';
  for (const byte of bytes) {
    group += ALPHABET[byte % ALPHABET.length];
  }
  return group;
}

export function generateCode(): string {
  const groups: string[] = [];
  for (let i = 0; i < GROUP_COUNT; i++) {
    groups.push(randomGroup());
  }
  return `HIEXT-${groups.join('-')}`;
}

/**
 * 从服务端密钥和稳定订单标识派生激活码。
 * 支付 webhook 重试时会得到同一个码，无需保存明文码。
 */
export async function deriveCode(secret: string, material: string): Promise<string> {
  if (secret.trim().length < 32 || !material.trim()) {
    throw new Error('license code derivation input is invalid');
  }
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign('HMAC', key, encoder.encode(material)),
  );
  const characters = Array.from(
    digest.slice(0, GROUP_LENGTH * GROUP_COUNT),
    (byte) => ALPHABET[byte & 31],
  ).join('');
  const groups = Array.from(
    { length: GROUP_COUNT },
    (_, index) => characters.slice(index * GROUP_LENGTH, (index + 1) * GROUP_LENGTH),
  );
  return `HIEXT-${groups.join('-')}`;
}

const CODE_PATTERN = /^HIEXT-[0-9A-HJKMNP-TV-Z]{5}(-[0-9A-HJKMNP-TV-Z]{5}){3}$/;

export function isValidCodeFormat(code: string): boolean {
  return CODE_PATTERN.test(code.trim().toUpperCase());
}

export function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}

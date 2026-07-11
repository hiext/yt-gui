/**
 * License code generation and format validation.
 * Format: HIEXT-XXXXX-XXXXX-XXXXX-XXXXX (Crockford Base32, ambiguous chars removed).
 */

// Crockford Base32 alphabet without I, L, O, U to avoid confusion.
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const GROUP_LENGTH = 5;
const GROUP_COUNT = 4;

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

const CODE_PATTERN = /^HIEXT-[0-9A-HJKMNP-TV-Z]{5}(-[0-9A-HJKMNP-TV-Z]{5}){3}$/;

export function isValidCodeFormat(code: string): boolean {
  return CODE_PATTERN.test(code.trim().toUpperCase());
}

export function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}

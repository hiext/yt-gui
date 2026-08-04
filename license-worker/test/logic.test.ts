import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';

// Provide Web Crypto for the modules under test (Workers-native API).
if (!globalThis.crypto) {
  // @ts-expect-error assign node webcrypto to global
  globalThis.crypto = webcrypto;
}

const { deriveCode, generateCode, isValidCodeFormat, normalizeCode } = await import('../src/codes.ts');
const { sha256Hex, signEntitlementToken } = await import('../src/crypto.ts');

test('generateCode produces valid HIEXT format', () => {
  for (let i = 0; i < 50; i++) {
    const code = generateCode();
    assert.match(code, /^HIEXT-[0-9A-HJKMNP-TV-Z]{5}(-[0-9A-HJKMNP-TV-Z]{5}){3}$/);
    assert.ok(isValidCodeFormat(code));
  }
});

test('isValidCodeFormat rejects bad codes', () => {
  assert.ok(!isValidCodeFormat('HIEXT-123'));
  assert.ok(!isValidCodeFormat('ABCDE-12345-12345-12345-12345'));
  assert.ok(!isValidCodeFormat('HIEXT-IIIII-12345-12345-12345')); // I not in alphabet
  assert.ok(!isValidCodeFormat(''));
});

test('normalizeCode uppercases and trims', () => {
  assert.equal(normalizeCode('  hiext-abcde-12345-fghij-67890  '), 'HIEXT-ABCDE-12345-FGHIJ-67890');
});

test('deriveCode is stable per order and keeps the public code format', async () => {
  const secret = '0123456789abcdef0123456789abcdef';
  const first = await deriveCode(secret, 'lemonsqueezy:order_created:1001');
  const retry = await deriveCode(secret, 'lemonsqueezy:order_created:1001');
  const other = await deriveCode(secret, 'lemonsqueezy:order_created:1002');
  assert.equal(first, retry);
  assert.notEqual(first, other);
  assert.ok(isValidCodeFormat(first));
});

test('sha256Hex is deterministic and 64 hex chars', async () => {
  const a = await sha256Hex('HIEXT-ABCDE-12345-FGHIJ-67890');
  const b = await sha256Hex('HIEXT-ABCDE-12345-FGHIJ-67890');
  assert.equal(a, b);
  assert.match(a, /^[0-9a-f]{64}$/);
});

test('signEntitlementToken produces verifiable Ed25519 token', async () => {
  // Generate a keypair for the test.
  const keyPair = await webcrypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']);
  const pkcs8 = Buffer.from(await webcrypto.subtle.exportKey('pkcs8', keyPair.privateKey)).toString('base64');

  const claims = { tier: 'pro' as const, fingerprint: 'fp123', licenseId: 'lic1', iat: 1000, exp: 2000 };
  const token = await signEntitlementToken(claims, pkcs8);

  const parts = token.split('.');
  assert.equal(parts.length, 3);

  // Verify signature with the public key.
  const signingInput = `${parts[0]}.${parts[1]}`;
  const sig = Uint8Array.from(Buffer.from(parts[2].replace(/-/g, '+').replace(/_/g, '/'), 'base64'));
  const valid = await webcrypto.subtle.verify('Ed25519', keyPair.publicKey, sig, new TextEncoder().encode(signingInput));
  assert.ok(valid);

  // Payload decodes to the original claims.
  const payload = JSON.parse(Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
  assert.deepEqual(payload, claims);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyTurnstile } from '../src/turnstile.ts';

test('verifyTurnstile returns ok when no secret configured', async () => {
  const r = await verifyTurnstile('any-token', undefined, '1.2.3.4');
  assert.ok(r.ok);
});

test('verifyTurnstile returns ok when secret is empty string', async () => {
  const r = await verifyTurnstile('any-token', '', '1.2.3.4');
  assert.ok(r.ok);
});

test('verifyTurnstile fails when token missing but secret set', async () => {
  const r = await verifyTurnstile('', 'secret-123', '1.2.3.4');
  assert.ok(!r.ok);
  assert.match(r.error ?? '', /missing/);
});

test('verifyTurnstile fails when token undefined but secret set', async () => {
  const r = await verifyTurnstile(undefined, 'secret-123', '1.2.3.4');
  assert.ok(!r.ok);
  assert.match(r.error ?? '', /missing/);
});

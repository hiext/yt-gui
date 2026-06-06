import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildIssuePayload,
  createWaitlistIssue,
  enforceWaitlistRateLimit,
  handleWaitlist,
  normalizeWaitlistPayload,
  validateWaitlistPayload,
} from '../../api/waitlist.mjs';
import { onRequest } from '../../functions/api/waitlist.js';

function createResponseRecorder() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

function createSharedRateLimitStore() {
  const store = new Map();

  return {
    async get(key) {
      return store.get(key) ?? null;
    },
    async put(key, value) {
      store.set(key, value);
    },
  };
}

test('normalizeWaitlistPayload trims supported fields', () => {
  const payload = normalizeWaitlistPayload({
    role: ' 自媒体剪辑 ',
    volume: ' 4-10 次 ',
    contact: ' user@example.com ',
    problem: ' 想减少批量失败重试 ',
    price: ' ￥79-129 ',
    website: ' ',
  });

  assert.deepEqual(payload, {
    role: '自媒体剪辑',
    volume: '4-10 次',
    contact: 'user@example.com',
    problem: '想减少批量失败重试',
    price: '￥79-129',
    website: '',
  });
});

test('normalizeWaitlistPayload parses urlencoded form bodies', () => {
  const payload = normalizeWaitlistPayload(
    'role=%E8%87%AA%E5%AA%92%E4%BD%93%E5%89%AA%E8%BE%91&volume=4-10+%E6%AC%A1&contact=user%40example.com&problem=%E6%89%B9%E9%87%8F%E4%BB%BB%E5%8A%A1&price=%EF%BF%A579-129&website=',
  );

  assert.deepEqual(payload, {
    role: '自媒体剪辑',
    volume: '4-10 次',
    contact: 'user@example.com',
    problem: '批量任务',
    price: '￥79-129',
    website: '',
  });
});

test('validateWaitlistPayload rejects invalid email', () => {
  const result = validateWaitlistPayload({
    role: '自媒体剪辑',
    volume: '4-10 次',
    contact: 'bad-email',
    problem: '',
    price: '￥79-129',
    website: '',
  });

  assert.equal(result.ok, false);
  assert.equal(result.error, '请填写有效的联系邮箱。');
});

test('validateWaitlistPayload accepts honeypot submissions without creating issue', () => {
  const result = validateWaitlistPayload({
    role: '自媒体剪辑',
    volume: '4-10 次',
    contact: 'user@example.com',
    problem: '',
    price: '￥79-129',
    website: 'bot-filled',
  });

  assert.equal(result.ok, true);
  assert.equal(result.honeypot, true);
});

test('buildIssuePayload includes private waitlist fields', () => {
  const result = buildIssuePayload(
    {
      role: '内容运营',
      volume: '10 次以上',
      contact: 'ops@example.com',
      problem: '@ops 请处理 #42 <script>',
      price: '￥129 以上，只要节省时间',
    },
    ['waitlist', 'pro'],
  );

  assert.equal(result.title, '[Pro 候补] 内容运营 / 10 次以上');
  assert.match(result.body, /联系邮箱：ops＠example.com/);
  assert.match(result.body, /＠ops 请处理 ＃42 ＜script＞/);
  assert.deepEqual(result.labels, ['waitlist', 'pro']);
});

test('createWaitlistIssue returns config error when environment is missing', async () => {
  const result = await createWaitlistIssue(
    {
      role: '内容运营',
      volume: '10 次以上',
      contact: 'ops@example.com',
      problem: '',
      price: '￥79-129',
      website: '',
    },
    {},
    async () => {
      throw new Error('should not call fetch');
    },
  );

  assert.equal(result.ok, false);
  assert.equal(result.status, 500);
});

test('createWaitlistIssue posts to GitHub issues API', async () => {
  const calls = [];
  const result = await createWaitlistIssue(
    {
      role: '课程资料归档',
      volume: '1-3 次',
      contact: 'archive@example.com',
      problem: '希望有更稳定的 Cookie 工作流。',
      price: '￥49-79',
      website: '',
    },
    {
      WAITLIST_GITHUB_TOKEN: 'token',
      WAITLIST_GITHUB_OWNER: 'hiext',
      WAITLIST_GITHUB_REPO: 'private-waitlist',
      WAITLIST_GITHUB_LABELS: 'waitlist, pro',
    },
    async (url, options) => {
      calls.push({ url, options });
      return {
        ok: true,
        async json() {
          return { number: 12, html_url: 'https://github.com/hiext/private-waitlist/issues/12' };
        },
      };
    },
  );

  assert.equal(result.ok, true);
  assert.deepEqual(result.data, { accepted: true });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://api.github.com/repos/hiext/private-waitlist/issues');
  assert.match(calls[0].options.headers.Authorization, /^Bearer /);
  assert.match(calls[0].options.body, /archive＠example.com/);
});

test('createWaitlistIssue returns fallback error when GitHub fetch throws', async () => {
  const result = await createWaitlistIssue(
    {
      role: '课程资料归档',
      volume: '1-3 次',
      contact: 'archive@example.com',
      problem: '希望有更稳定的 Cookie 工作流。',
      price: '￥49-79',
      website: '',
    },
    {
      WAITLIST_GITHUB_TOKEN: 'token',
      WAITLIST_GITHUB_OWNER: 'hiext',
      WAITLIST_GITHUB_REPO: 'private-waitlist',
    },
    async () => {
      throw new Error('network failure');
    },
  );

  assert.equal(result.ok, false);
  assert.equal(result.status, 502);
});

test('enforceWaitlistRateLimit throttles repeated email submissions', async () => {
  const state = {
    ip: new Map(),
    email: new Map(),
  };
  const headers = {
    origin: 'https://hiext.example.com',
    host: 'hiext.example.com',
    'x-forwarded-for': '203.0.113.10',
  };
  const payload = {
    contact: 'repeat@example.com',
  };

  const first = await enforceWaitlistRateLimit(headers, payload, state, 1000);
  const second = await enforceWaitlistRateLimit(headers, payload, state, 2000);
  const third = await enforceWaitlistRateLimit(headers, payload, state, 3000);

  assert.equal(first.ok, true);
  assert.equal(second.ok, true);
  assert.equal(third.ok, false);
  assert.equal(third.status, 429);
});

test('enforceWaitlistRateLimit can use shared KV-like storage across isolated states', async () => {
  const sharedStore = createSharedRateLimitStore();
  const headers = {
    origin: 'https://hiext.example.com',
    host: 'hiext.example.com',
    'cf-connecting-ip': '203.0.113.20',
  };
  const payload = {
    contact: 'shared@example.com',
  };

  const first = await enforceWaitlistRateLimit(headers, payload, { ip: new Map(), email: new Map() }, 1000, sharedStore);
  const second = await enforceWaitlistRateLimit(headers, payload, { ip: new Map(), email: new Map() }, 2000, sharedStore);
  const third = await enforceWaitlistRateLimit(headers, payload, { ip: new Map(), email: new Map() }, 3000, sharedStore);

  assert.equal(first.ok, true);
  assert.equal(second.ok, true);
  assert.equal(third.ok, false);
  assert.equal(third.status, 429);
});

test('handleWaitlist returns 405 for non-POST methods', async () => {
  const response = createResponseRecorder();

  await handleWaitlist({ method: 'GET' }, response, {});

  assert.equal(response.statusCode, 405);
  assert.equal(response.body.success, false);
});

test('handleWaitlist returns 403 for cross-origin submissions', async () => {
  const response = createResponseRecorder();

  await handleWaitlist(
    {
      method: 'POST',
      headers: {
        origin: 'https://evil.example.com',
        host: 'hiext.example.com',
      },
      body: {
        role: '自媒体剪辑',
        volume: '4-10 次',
        contact: 'user@example.com',
        problem: '',
        price: '￥79-129',
        website: '',
      },
    },
    response,
    {},
  );

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.success, false);
});

test('handleWaitlist returns 202 for honeypot submissions', async () => {
  const response = createResponseRecorder();

  await handleWaitlist(
    {
      method: 'POST',
      headers: {
        origin: 'https://hiext.example.com',
        host: 'hiext.example.com',
      },
      body: {
        role: '自媒体剪辑',
        volume: '4-10 次',
        contact: 'user@example.com',
        problem: '',
        price: '￥79-129',
        website: 'spam',
      },
    },
    response,
    {},
  );

  assert.equal(response.statusCode, 202);
  assert.equal(response.body.success, true);
});

test('handleWaitlist returns 200 after successful GitHub issue creation', async () => {
  const response = createResponseRecorder();

  await handleWaitlist(
    {
      method: 'POST',
      headers: {
        origin: 'https://hiext.example.com',
        host: 'hiext.example.com',
      },
      body: {
        role: '研究型采集',
        volume: '10 次以上',
        contact: 'lab@example.com',
        problem: '想降低中断恢复成本。',
        price: '￥129 以上，只要节省时间',
        website: '',
      },
    },
    response,
    {
      env: {
        WAITLIST_GITHUB_TOKEN: 'token',
        WAITLIST_GITHUB_OWNER: 'hiext',
        WAITLIST_GITHUB_REPO: 'private-waitlist',
      },
      fetchImpl: async () => ({
        ok: true,
        async json() {
          return { number: 24, html_url: 'https://github.com/hiext/private-waitlist/issues/24' };
        },
      }),
    },
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.success, true);
  assert.deepEqual(response.body.data, { accepted: true });
});

test('onRequest returns 405 with JSON response for non-POST methods', async () => {
  const response = await onRequest({
    env: {},
    request: new Request('https://hiext.example.com/api/waitlist', { method: 'GET' }),
  });

  assert.equal(response.status, 405);
  assert.match(response.headers.get('content-type') || '', /application\/json/);
  assert.deepEqual(await response.json(), { success: false, error: '仅支持 POST 提交。' });
});

test('onRequest returns 500 when shared rate-limit storage is not configured', async () => {
  const response = await onRequest({
    env: {},
    request: new Request('https://hiext.example.com/api/waitlist', {
      method: 'POST',
      headers: new Headers({
        'content-type': 'application/json',
        origin: 'https://hiext.example.com',
        'x-forwarded-host': 'hiext.example.com',
      }),
      body: JSON.stringify({
        role: '自媒体剪辑',
        volume: '4-10 次',
        contact: 'user@example.com',
        problem: '需要更稳定的批量流程。',
        price: '￥79-129',
        website: '',
      }),
    }),
  });

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), {
    success: false,
    error: '私有候补通道限流存储未配置完成，请稍后再试。',
  });
});

test('onRequest reads Headers object and blocks cross-origin submissions', async () => {
  const response = await onRequest({
    env: {
      WAITLIST_RATE_LIMIT_KV: createSharedRateLimitStore(),
    },
    request: new Request('https://hiext.example.com/api/waitlist', {
      method: 'POST',
      headers: new Headers({
        'content-type': 'application/json',
        origin: 'https://evil.example.com',
        'x-forwarded-host': 'hiext.example.com',
      }),
      body: JSON.stringify({
        role: '自媒体剪辑',
        volume: '4-10 次',
        contact: 'user@example.com',
        problem: '需要更稳定的批量流程。',
        price: '￥79-129',
        website: '',
      }),
    }),
  });

  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { success: false, error: '提交来源无效。' });
});

test('onRequest accepts urlencoded form submissions on Cloudflare Pages', async () => {
  const response = await onRequest({
    env: {
      WAITLIST_GITHUB_TOKEN: 'token',
      WAITLIST_GITHUB_OWNER: 'hiext',
      WAITLIST_GITHUB_REPO: 'private-waitlist',
      WAITLIST_RATE_LIMIT_KV: createSharedRateLimitStore(),
    },
    fetchImpl: async () => ({
      ok: true,
      async json() {
        return { number: 31, html_url: 'https://github.com/hiext/private-waitlist/issues/31' };
      },
    }),
    request: new Request('https://hiext.example.com/api/waitlist', {
      method: 'POST',
      headers: new Headers({
        'content-type': 'application/x-www-form-urlencoded',
        origin: 'https://hiext.example.com',
        'x-forwarded-host': 'hiext.example.com',
        'x-forwarded-for': '203.0.113.25',
      }),
      body: new URLSearchParams({
        role: '内容运营',
        volume: '4-10 次',
        contact: 'ops@example.com',
        problem: '希望减少失败任务的重新组织成本。',
        price: '￥79-129',
        website: '',
      }).toString(),
    }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { success: true, data: { accepted: true } });
});

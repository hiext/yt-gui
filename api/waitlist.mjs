const ALLOWED_ROLES = new Set(['自媒体剪辑', '内容运营', '课程资料归档', '研究型采集', '其他']);
const ALLOWED_VOLUMES = new Set(['1-3 次', '4-10 次', '10 次以上']);
const ALLOWED_PRICES = new Set(['￥49-79', '￥79-129', '￥129 以上，只要节省时间']);
const IP_RATE_LIMIT_MAX = 5;
const IP_RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const EMAIL_RATE_LIMIT_MAX = 2;
const EMAIL_RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000;

function toCleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function readRequestBody(body) {
  if (body == null) {
    return {};
  }

  if (typeof body === 'string') {
    const trimmed = body.trim();

    if (!trimmed) {
      return {};
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return JSON.parse(trimmed);
      } catch {
        return null;
      }
    }

    const formData = new URLSearchParams(body);
    return Object.fromEntries(formData.entries());
  }

  if (typeof body === 'object') {
    return body;
  }

  return null;
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function normalizeLabels(value) {
  return toCleanString(value)
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function sanitizeIssueText(value) {
  return toCleanString(value)
    .replace(/\r\n?/g, '\n')
    .replace(/@/g, '＠')
    .replace(/#/g, '＃')
    .replace(/</g, '＜')
    .replace(/>/g, '＞');
}

function readHeader(headers, name) {
  if (!headers) {
    return '';
  }

  if (typeof headers.get === 'function') {
    return toCleanString(
      headers.get(name) ?? headers.get(name.toLowerCase()) ?? headers.get(name.toUpperCase()),
    );
  }

  if (typeof headers !== 'object') {
    return '';
  }

  const directValue = headers[name] ?? headers[name.toLowerCase()] ?? headers[name.toUpperCase()];
  return toCleanString(directValue);
}

function isAllowedOrigin(headers) {
  const host = readHeader(headers, 'x-forwarded-host') || readHeader(headers, 'host');
  const origin = readHeader(headers, 'origin');
  const referer = readHeader(headers, 'referer');

  if (!host) {
    return false;
  }

  try {
    if (origin) {
      return new URL(origin).host === host;
    }

    if (referer) {
      return new URL(referer).host === host;
    }
  } catch {
    return false;
  }

  return false;
}

function createRateLimitState() {
  return {
    ip: new Map(),
    email: new Map(),
  };
}

const defaultRateLimitState = createRateLimitState();

function getClientIp(headers) {
  const forwardedFor = readHeader(headers, 'cf-connecting-ip') || readHeader(headers, 'x-forwarded-for');

  if (!forwardedFor) {
    return 'unknown';
  }

  return forwardedFor.split(',')[0].trim() || 'unknown';
}

function parseRateLimitTimestamps(value) {
  if (!value) {
    return [];
  }

  try {
    const parsed = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed.filter((timestamp) => Number.isFinite(timestamp));
  } catch {
    return [];
  }
}

function getSharedRateLimitStore(sharedStore) {
  if (!sharedStore || typeof sharedStore.get !== 'function' || typeof sharedStore.put !== 'function') {
    return null;
  }

  return sharedStore;
}

function consumeMemoryRateLimit(store, key, maxRequests, windowMs, now) {
  const recent = (store.get(key) || []).filter((timestamp) => now - timestamp < windowMs);

  if (recent.length >= maxRequests) {
    store.set(key, recent);
    return false;
  }

  recent.push(now);
  store.set(key, recent);
  return true;
}

async function consumeSharedRateLimit(store, key, maxRequests, windowMs, now) {
  const recent = parseRateLimitTimestamps(await store.get(key)).filter(
    (timestamp) => now - timestamp < windowMs,
  );

  if (recent.length >= maxRequests) {
    await store.put(key, JSON.stringify(recent), {
      expirationTtl: Math.max(60, Math.ceil(windowMs / 1000)),
    });
    return false;
  }

  recent.push(now);
  await store.put(key, JSON.stringify(recent), {
    expirationTtl: Math.max(60, Math.ceil(windowMs / 1000)),
  });
  return true;
}

export async function enforceWaitlistRateLimit(
  headers,
  payload,
  state = defaultRateLimitState,
  now = Date.now(),
  sharedStore,
) {
  const clientIp = getClientIp(headers);
  const email = payload.contact.toLowerCase();
  const rateLimitStore = getSharedRateLimitStore(sharedStore);
  const consumeRateLimit = rateLimitStore ? consumeSharedRateLimit : consumeMemoryRateLimit;
  const ipStore = rateLimitStore ?? state.ip;
  const emailStore = rateLimitStore ?? state.email;

  if (!(await consumeRateLimit(ipStore, `ip:${clientIp}`, IP_RATE_LIMIT_MAX, IP_RATE_LIMIT_WINDOW_MS, now))) {
    return { ok: false, status: 429, error: '提交过于频繁，请稍后再试。' };
  }

  if (
    !(await consumeRateLimit(emailStore, `email:${email}`, EMAIL_RATE_LIMIT_MAX, EMAIL_RATE_LIMIT_WINDOW_MS, now))
  ) {
    return { ok: false, status: 429, error: '相同邮箱提交过于频繁，请明天再试。' };
  }

  return { ok: true };
}

export function normalizeWaitlistPayload(body) {
  const source = readRequestBody(body);

  if (!source || Array.isArray(source)) {
    return null;
  }

  return {
    role: toCleanString(source.role),
    volume: toCleanString(source.volume),
    contact: toCleanString(source.contact),
    problem: toCleanString(source.problem),
    price: toCleanString(source.price),
    website: toCleanString(source.website),
  };
}

export function validateWaitlistPayload(payload) {
  if (!payload) {
    return { ok: false, error: '请求体格式无效。' };
  }

  if (payload.website) {
    return { ok: true, honeypot: true, value: payload };
  }

  if (!ALLOWED_ROLES.has(payload.role)) {
    return { ok: false, error: '角色字段无效。' };
  }

  if (!ALLOWED_VOLUMES.has(payload.volume)) {
    return { ok: false, error: '下载频率字段无效。' };
  }

  if (!isValidEmail(payload.contact) || payload.contact.length > 160) {
    return { ok: false, error: '请填写有效的联系邮箱。' };
  }

  if (!ALLOWED_PRICES.has(payload.price)) {
    return { ok: false, error: '价格区间字段无效。' };
  }

  if (payload.problem.length > 2000) {
    return { ok: false, error: '问题描述过长，请控制在 2000 字以内。' };
  }

  return { ok: true, honeypot: false, value: payload };
}

export function buildIssuePayload(payload, labels) {
  const title = `[Pro 候补] ${payload.role} / ${payload.volume}`;
  const body = [
    '## Pro 私有候补登记',
    '',
    `- 角色：${payload.role}`,
    `- 每周下载频率：${payload.volume}`,
    `- 联系邮箱：${sanitizeIssueText(payload.contact)}`,
    `- 可接受价格区间：${payload.price}`,
    '',
    '## 最想优先解决的问题',
    '',
    sanitizeIssueText(payload.problem) || '未填写',
  ].join('\n');

  return {
    title,
    body,
    labels,
  };
}

export async function createWaitlistIssue(payload, env = process.env, fetchImpl = fetch) {
  const token = toCleanString(env.WAITLIST_GITHUB_TOKEN);
  const owner = toCleanString(env.WAITLIST_GITHUB_OWNER);
  const repo = toCleanString(env.WAITLIST_GITHUB_REPO);

  if (!token || !owner || !repo) {
    return {
      ok: false,
      status: 500,
      error: '私有候补通道暂未配置完成，请先复制登记内容备用。',
    };
  }

  const issuePayload = buildIssuePayload(payload, normalizeLabels(env.WAITLIST_GITHUB_LABELS));

  try {
    const response = await fetchImpl(`https://api.github.com/repos/${owner}/${repo}/issues`, {
      method: 'POST',
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        'User-Agent': 'hiext-yt-gui-waitlist',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: JSON.stringify(issuePayload),
    });

    if (!response.ok) {
      const responseBody = await response.text();
      console.error('waitlist github issue creation failed', {
        responseBody,
        status: response.status,
        statusText: response.statusText,
      });
      return {
        ok: false,
        status: 502,
        error: '私有候补通道暂时不可用，请先复制登记内容备用。',
      };
    }

    return {
      ok: true,
      status: 200,
      data: {
        accepted: true,
      },
    };
  } catch (error) {
    console.error('waitlist github issue request threw', {
      message: error instanceof Error ? error.message : String(error),
    });
    return {
      ok: false,
      status: 502,
      error: '私有候补通道暂时不可用，请先复制登记内容备用。',
    };
  }
}

export async function handleWaitlist(request, response, options = {}) {
  const result = await handleWaitlistRequest(request, options);
  return response.status(result.status).json(result.body);
}

export async function handleWaitlistRequest(request, options = {}) {
  if (request.method !== 'POST') {
    return { status: 405, body: { success: false, error: '仅支持 POST 提交。' } };
  }

  if (!isAllowedOrigin(request.headers)) {
    return { status: 403, body: { success: false, error: '提交来源无效。' } };
  }

  const payload = normalizeWaitlistPayload(request.body);
  const validation = validateWaitlistPayload(payload);

  if (!validation.ok) {
    return { status: 400, body: { success: false, error: validation.error } };
  }

  if (validation.honeypot) {
    return { status: 202, body: { success: true, data: { accepted: true } } };
  }

  const rateLimit = await enforceWaitlistRateLimit(
    request.headers,
    validation.value,
    options.rateLimitState,
    options.now,
    options.env?.WAITLIST_RATE_LIMIT_KV,
  );

  if (!rateLimit.ok) {
    return { status: rateLimit.status, body: { success: false, error: rateLimit.error } };
  }

  const result = await createWaitlistIssue(
    validation.value,
    options.env ?? process.env,
    options.fetchImpl ?? fetch,
  );

  if (!result.ok) {
    return { status: result.status, body: { success: false, error: result.error } };
  }

  return { status: 200, body: { success: true, data: result.data } };
}

export default async function handler(request, response) {
  return handleWaitlist(request, response);
}

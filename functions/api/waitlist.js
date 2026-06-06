import { handleWaitlistRequest } from '../../api/waitlist.mjs';

function createJsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'cache-control': 'no-store',
      'content-type': 'application/json; charset=UTF-8',
    },
  });
}

async function readCloudflareRequestBody(request) {
  const contentType = (request.headers.get('content-type') || '').toLowerCase();

  if (!contentType) {
    return {};
  }

  if (contentType.includes('multipart/form-data')) {
    const formData = await request.formData();
    return Object.fromEntries(
      Array.from(formData.entries(), ([key, value]) => [key, typeof value === 'string' ? value : '']),
    );
  }

  return request.text();
}

function hasSharedRateLimitBinding(env) {
  return Boolean(
    env &&
      env.WAITLIST_RATE_LIMIT_KV &&
      typeof env.WAITLIST_RATE_LIMIT_KV.get === 'function' &&
      typeof env.WAITLIST_RATE_LIMIT_KV.put === 'function',
  );
}

export async function onRequest(context) {
  const { allowInMemoryRateLimit, env, fetchImpl, now, rateLimitState, request } = context;

  if (request.method === 'POST' && !allowInMemoryRateLimit && !hasSharedRateLimitBinding(env)) {
    return createJsonResponse(500, {
      success: false,
      error: '私有候补通道限流存储未配置完成，请稍后再试。',
    });
  }

  const body = request.method === 'POST' ? await readCloudflareRequestBody(request) : undefined;
  const result = await handleWaitlistRequest(
    {
      method: request.method,
      headers: request.headers,
      body,
    },
    {
      env,
      fetchImpl: fetchImpl ?? ((...args) => fetch(...args)),
      now,
      rateLimitState,
    },
  );

  return createJsonResponse(result.status, result.body);
}

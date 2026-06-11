import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { createApp } from '../../cloud/server.mjs';

test('personal cloud server handles health, pairing, media package and jobs', async () => {
  const dataDir = await mkdtemp(path.join(tmpdir(), 'edge-cloud-clips-'));
  const server = createServer(
    createApp({
      dataDir,
      pairingToken: 'pair-me',
      accessToken: 'token-1',
      clipRunner: async ({ outputPath, candidate }) => {
        await writeFile(outputPath, Buffer.from(`clip:${candidate.id}`));
      },
    }),
  );
  await listen(server);

  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const health = await requestJson(baseUrl, 'GET', '/api/health');
    assert.equal(health.status, 200);
    assert.equal(health.body.ok, true);

    const pair = await requestJson(baseUrl, 'POST', '/api/devices/pair', {
      deviceName: 'mac',
      pairingToken: 'pair-me',
    });
    assert.equal(pair.status, 200);
    assert.equal(pair.body.accessToken, 'token-1');

    const unauthorized = await requestJson(
      baseUrl,
      'POST',
      '/api/media/analysis-package',
      { mediaAsset: { id: 'asset-1' } },
    );
    assert.equal(unauthorized.status, 401);

    const media = await requestJson(
      baseUrl,
      'POST',
      '/api/media/analysis-package',
      {
        mediaAsset: { id: 'asset-1', title: 'Video' },
        clipCandidates: [{ id: 'candidate-1' }],
        uploadPolicy: 'manifestOnly',
      },
      'token-1',
    );
    assert.equal(media.status, 200);
    assert.match(media.body.cloudMediaId, /^media_/);

    const job = await requestJson(
      baseUrl,
      'POST',
      '/api/clip-jobs',
      {
        cloudMediaId: media.body.cloudMediaId,
        candidateIds: ['candidate-1'],
        uploadOriginal: false,
      },
      'token-1',
    );
    assert.equal(job.status, 200);
    assert.match(job.body.cloudJobId, /^job_/);

    const upload = await requestJson(
      baseUrl,
      'POST',
      `/api/media/${media.body.cloudMediaId}/uploads/init`,
      {
        fileName: 'video.mp4',
        totalBytes: 4,
        sha256: '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
        chunkSize: 4,
      },
      'token-1',
    );
    assert.equal(upload.status, 200);
    assert.match(upload.body.uploadId, /^upload_/);

    const uploadStatusBefore = await requestJson(
      baseUrl,
      'GET',
      `/api/media/${media.body.cloudMediaId}/uploads/${upload.body.uploadId}`,
      undefined,
      'token-1',
    );
    assert.equal(uploadStatusBefore.status, 200);
    assert.deepEqual(uploadStatusBefore.body.uploadedChunks, []);

    const chunk = await requestBytes(
      baseUrl,
      'PUT',
      `/api/media/${media.body.cloudMediaId}/uploads/${upload.body.uploadId}/chunks/0`,
      Buffer.from([1, 2, 3, 4]),
      'token-1',
    );
    assert.equal(chunk.status, 200);
    assert.equal(chunk.body.receivedBytes, 4);

    const uploadStatusAfterChunk = await requestJson(
      baseUrl,
      'GET',
      `/api/media/${media.body.cloudMediaId}/uploads/${upload.body.uploadId}`,
      undefined,
      'token-1',
    );
    assert.deepEqual(uploadStatusAfterChunk.body.uploadedChunks, [0]);

    const complete = await requestJson(
      baseUrl,
      'POST',
      `/api/media/${media.body.cloudMediaId}/uploads/${upload.body.uploadId}/complete`,
      {
        sha256: '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
      },
      'token-1',
    );
    assert.equal(complete.status, 200);
    assert.equal(complete.body.totalBytes, 4);

    const status = await requestJson(
      baseUrl,
      'GET',
      `/api/clip-jobs/${job.body.cloudJobId}`,
      undefined,
      'token-1',
    );
    assert.equal(status.status, 200);
    assert.equal(status.body.status, 'queued');

    const worker = await requestJson(
      baseUrl,
      'POST',
      `/api/clip-jobs/${job.body.cloudJobId}/run`,
      undefined,
      'token-1',
    );
    assert.equal(worker.status, 200);
    assert.equal(worker.body.status, 'completed');

    const result = await requestJson(
      baseUrl,
      'GET',
      `/api/clip-jobs/${job.body.cloudJobId}/result-manifest`,
      undefined,
      'token-1',
    );
    assert.equal(result.status, 200);
    assert.equal(result.body.status, 'completed');
    assert.equal(result.body.clips.length, 1);
    assert.equal(result.body.clips[0].candidateId, 'candidate-1');
    assert.match(result.body.clips[0].downloadPath, /candidate-1\.mp4$/);

    const clipFile = await requestRaw(
      baseUrl,
      'GET',
      result.body.clips[0].downloadPath,
      'token-1',
    );
    assert.equal(clipFile.status, 200);
    assert.equal(clipFile.body.toString('utf8'), 'clip:candidate-1');

    const manifestFile = await readFile(
      path.join(dataDir, 'manifests', `${job.body.cloudJobId}.json`),
      'utf8',
    );
    assert.match(manifestFile, /candidate-1/);

    const cancelUpload = await requestJson(
      baseUrl,
      'POST',
      `/api/media/${media.body.cloudMediaId}/uploads/init`,
      {
        fileName: 'cancel.mp4',
        totalBytes: 4,
        sha256: '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
        chunkSize: 4,
      },
      'token-1',
    );
    const cancelled = await requestJson(
      baseUrl,
      'DELETE',
      `/api/media/${media.body.cloudMediaId}/uploads/${cancelUpload.body.uploadId}`,
      undefined,
      'token-1',
    );
    assert.equal(cancelled.status, 200);
    assert.equal(cancelled.body.status, 'cancelled');

    const rejectedChunk = await requestBytes(
      baseUrl,
      'PUT',
      `/api/media/${media.body.cloudMediaId}/uploads/${cancelUpload.body.uploadId}/chunks/0`,
      Buffer.from([1, 2, 3, 4]),
      'token-1',
    );
    assert.equal(rejectedChunk.status, 409);
  } finally {
    await close(server);
    await rm(dataDir, { recursive: true, force: true });
  }
});

async function requestJson(baseUrl, method, pathName, body, token) {
  const response = await fetch(`${baseUrl}${pathName}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return {
    status: response.status,
    body: await response.json(),
  };
}

async function requestRaw(baseUrl, method, pathName, token) {
  const response = await fetch(`${baseUrl}${pathName}`, {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
  });
  return {
    status: response.status,
    body: Buffer.from(await response.arrayBuffer()),
  };
}

async function requestBytes(baseUrl, method, pathName, body, token) {
  const response = await fetch(`${baseUrl}${pathName}`, {
    method,
    headers: {
      'content-type': 'application/octet-stream',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body,
  });
  return {
    status: response.status,
    body: await response.json(),
  };
}

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

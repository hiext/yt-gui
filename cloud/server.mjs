import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdir, readFile, readdir, rename, writeFile } from 'node:fs/promises';
import { createWriteStream } from 'node:fs';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_PORT = Number.parseInt(process.env.PORT ?? '8731', 10);
const DEFAULT_DATA_DIR = process.env.DATA_DIR ?? path.join(process.cwd(), 'data');

export function createApp(options = {}) {
  const dataDir = options.dataDir ?? DEFAULT_DATA_DIR;
  const pairingToken = options.pairingToken ?? process.env.PAIRING_TOKEN ?? 'change-me';
  const accessToken = effectiveAccessToken(
    options.accessToken ?? process.env.ACCESS_TOKEN,
    pairingToken,
  );
  const clipRunner = options.clipRunner ?? defaultClipRunner;

  return async function handleRequest(req, res) {
    try {
      await route({
        req,
        res,
        dataDir,
        pairingToken,
        accessToken,
        clipRunner,
      });
    } catch (error) {
      sendJson(res, 500, { error: error.message || 'internal server error' });
    }
  };
}

async function route({ req, res, dataDir, pairingToken, accessToken, clipRunner }) {
  const url = new URL(req.url, 'http://localhost');
  log('request', { method: req.method, path: url.pathname });

  if (req.method === 'GET' && url.pathname === '/api/health') {
    sendJson(res, 200, { ok: true, version: 'edge-cloud-clips-0.1.0' });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/devices/pair') {
    const body = await readJson(req);
    if (!safeEqual(String(body.pairingToken ?? ''), pairingToken)) {
      sendJson(res, 401, { error: 'invalid pairing token' });
      return;
    }
    const deviceId = `dev_${hashText(String(body.deviceName ?? 'device')).slice(0, 12)}`;
    const token = accessToken || `local_${hashText(`${deviceId}:${pairingToken}`).slice(0, 32)}`;
    sendJson(res, 200, { deviceId, accessToken: token });
    return;
  }

  if (!authorized(req, accessToken)) {
    sendJson(res, 401, { error: 'missing or invalid access token' });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/media/analysis-package') {
    const body = await readJson(req);
    const cloudMediaId = body.mediaAsset?.id
      ? `media_${hashText(String(body.mediaAsset.id)).slice(0, 16)}`
      : `media_${randomUUID()}`;
    await writeJson(dataDir, 'media', `${cloudMediaId}.json`, {
      ...body,
      cloudMediaId,
      storedAt: new Date().toISOString(),
    });
    sendJson(res, 200, { cloudMediaId });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/clip-jobs') {
    const body = await readJson(req);
    const cloudJobId = `job_${randomUUID()}`;
    const job = {
      cloudJobId,
      cloudMediaId: body.cloudMediaId,
      candidateIds: Array.isArray(body.candidateIds) ? body.candidateIds : [],
      uploadOriginal: body.uploadOriginal === true,
      status: 'queued',
      progress: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    await writeJson(dataDir, 'jobs', `${cloudJobId}.json`, job);
    sendJson(res, 200, { cloudJobId });
    return;
  }

  const uploadInitMatch = url.pathname.match(
    /^\/api\/media\/([^/]+)\/uploads\/init$/,
  );
  if (req.method === 'POST' && uploadInitMatch) {
    const cloudMediaId = uploadInitMatch[1];
    const body = await readJson(req);
    const uploadId = `upload_${randomUUID()}`;
    const upload = {
      uploadId,
      cloudMediaId,
      fileName: safeFileName(String(body.fileName ?? 'original.bin')),
      totalBytes: Number(body.totalBytes ?? 0),
      sha256: String(body.sha256 ?? ''),
      chunkSize: Math.max(1, Number(body.chunkSize ?? 8 * 1024 * 1024)),
      uploadedChunks: [],
      status: 'uploading',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    await writeJson(
      dataDir,
      path.join('uploads', cloudMediaId, uploadId),
      'state.json',
      upload,
    );
    sendJson(res, 200, {
      uploadId,
      chunkSize: upload.chunkSize,
      uploadedChunks: [],
    });
    return;
  }

  const chunkMatch = url.pathname.match(
    /^\/api\/media\/([^/]+)\/uploads\/([^/]+)\/chunks\/(\d+)$/,
  );
  if (req.method === 'PUT' && chunkMatch) {
    const [, cloudMediaId, uploadId, rawIndex] = chunkMatch;
    const chunkIndex = Number(rawIndex);
    const upload = await readStoredJson(
      dataDir,
      'uploads',
      path.join(cloudMediaId, uploadId, 'state.json'),
    );
    if (!upload) {
      sendJson(res, 404, { error: 'upload not found' });
      return;
    }
    if (upload.status === 'cancelled') {
      sendJson(res, 409, { error: 'upload cancelled' });
      return;
    }
    const chunkDir = path.join(dataDir, 'uploads', cloudMediaId, uploadId, 'chunks');
    await mkdir(chunkDir, { recursive: true });
    const chunkPath = path.join(chunkDir, `${chunkIndex}.part`);
    const receivedBytes = await writeRequestBody(req, chunkPath);
    const uploadedChunks = new Set(upload.uploadedChunks ?? []);
    uploadedChunks.add(chunkIndex);
    const updated = {
      ...upload,
      uploadedChunks: [...uploadedChunks].sort((a, b) => a - b),
      updatedAt: new Date().toISOString(),
    };
    await writeJson(
      dataDir,
      path.join('uploads', cloudMediaId, uploadId),
      'state.json',
      updated,
    );
    sendJson(res, 200, { uploadId, chunkIndex, receivedBytes });
    return;
  }

  const uploadStatusMatch = url.pathname.match(
    /^\/api\/media\/([^/]+)\/uploads\/([^/]+)$/,
  );
  if (uploadStatusMatch) {
    const [, cloudMediaId, uploadId] = uploadStatusMatch;
    const upload = await readStoredJson(
      dataDir,
      'uploads',
      path.join(cloudMediaId, uploadId, 'state.json'),
    );
    if (!upload) {
      sendJson(res, 404, { error: 'upload not found' });
      return;
    }
    if (req.method === 'GET') {
      sendJson(res, 200, upload);
      return;
    }
    if (req.method === 'DELETE') {
      const cancelled = {
        ...upload,
        status: 'cancelled',
        updatedAt: new Date().toISOString(),
      };
      await writeJson(
        dataDir,
        path.join('uploads', cloudMediaId, uploadId),
        'state.json',
        cancelled,
      );
      sendJson(res, 200, cancelled);
      return;
    }
  }

  const uploadCompleteMatch = url.pathname.match(
    /^\/api\/media\/([^/]+)\/uploads\/([^/]+)\/complete$/,
  );
  if (req.method === 'POST' && uploadCompleteMatch) {
    const [, cloudMediaId, uploadId] = uploadCompleteMatch;
    const body = await readJson(req);
    const upload = await readStoredJson(
      dataDir,
      'uploads',
      path.join(cloudMediaId, uploadId, 'state.json'),
    );
    if (!upload) {
      sendJson(res, 404, { error: 'upload not found' });
      return;
    }
    if (upload.status === 'cancelled') {
      sendJson(res, 409, { error: 'upload cancelled' });
      return;
    }
    if (upload.sha256 && body.sha256 && upload.sha256 !== body.sha256) {
      sendJson(res, 409, { error: 'sha256 mismatch' });
      return;
    }
    const objectDir = path.join(dataDir, 'objects', cloudMediaId);
    await mkdir(objectDir, { recursive: true });
    const objectPath = path.join(objectDir, upload.fileName);
    await assembleChunks({
      chunksDir: path.join(dataDir, 'uploads', cloudMediaId, uploadId, 'chunks'),
      outputPath: objectPath,
    });
    const actualSha256 = hashBuffer(await readFile(objectPath));
    if (upload.sha256 && upload.sha256 !== actualSha256) {
      sendJson(res, 409, { error: 'assembled sha256 mismatch' });
      return;
    }
    const completed = {
      ...upload,
      status: 'completed',
      objectPath,
      updatedAt: new Date().toISOString(),
    };
    await writeJson(
      dataDir,
      path.join('uploads', cloudMediaId, uploadId),
      'state.json',
      completed,
    );
    sendJson(res, 200, {
      cloudMediaId,
      objectPath,
      totalBytes: upload.totalBytes,
    });
    return;
  }

  const jobMatch = url.pathname.match(/^\/api\/clip-jobs\/([^/]+)$/);
  if (req.method === 'GET' && jobMatch) {
    const cloudJobId = jobMatch[1];
    const job = await readStoredJson(dataDir, 'jobs', `${cloudJobId}.json`);
    if (!job) {
      sendJson(res, 404, { error: 'job not found' });
      return;
    }
    sendJson(res, 200, job);
    return;
  }

  const runJobMatch = url.pathname.match(/^\/api\/clip-jobs\/([^/]+)\/run$/);
  if (req.method === 'POST' && runJobMatch) {
    const cloudJobId = runJobMatch[1];
    const job = await readStoredJson(dataDir, 'jobs', `${cloudJobId}.json`);
    if (!job) {
      sendJson(res, 404, { error: 'job not found' });
      return;
    }
    const result = await runClipJob(dataDir, job, clipRunner);
    sendJson(res, 200, result);
    return;
  }

  const resultMatch = url.pathname.match(
    /^\/api\/clip-jobs\/([^/]+)\/result-manifest$/,
  );
  if (req.method === 'GET' && resultMatch) {
    const cloudJobId = resultMatch[1];
    const manifest = await readStoredJson(
      dataDir,
      'manifests',
      `${cloudJobId}.json`,
    );
    if (!manifest) {
      sendJson(res, 404, { error: 'result manifest not found' });
      return;
    }
    sendJson(res, 200, manifest);
    return;
  }

  const fileMatch = url.pathname.match(
    /^\/api\/clip-jobs\/([^/]+)\/files\/([^/]+)$/,
  );
  if (req.method === 'GET' && fileMatch) {
    const [, cloudJobId, fileName] = fileMatch;
    const filePath = path.join(dataDir, 'clips', cloudJobId, safeFileName(fileName));
    try {
      const bytes = await readFile(filePath);
      res.statusCode = 200;
      res.setHeader('content-type', 'video/mp4');
      res.end(bytes);
    } catch (error) {
      if (error.code === 'ENOENT') {
        sendJson(res, 404, { error: 'clip file not found' });
        return;
      }
      throw error;
    }
    return;
  }

  sendJson(res, 404, { error: 'not found' });
}

function effectiveAccessToken(configuredToken, pairingToken) {
  if (configuredToken && String(configuredToken).trim()) {
    return String(configuredToken).trim();
  }
  return `local_${hashText(`access:${pairingToken}`).slice(0, 32)}`;
}

function authorized(req, accessToken) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  return safeEqual(token, accessToken);
}

async function readJson(req) {
  const chunks = [];
  let totalBytes = 0;
  for await (const chunk of req) {
    totalBytes += chunk.length;
    if (totalBytes > MAX_REQUEST_BODY) {
      throw Object.assign(new Error('Request body too large'), { statusCode: 413 });
    }
    chunks.push(chunk);
  }
  const text = Buffer.concat(chunks).toString('utf8');
  if (!text.trim()) return {};
  return JSON.parse(text);
}

const MAX_REQUEST_BODY = 128 * 1024 * 1024; // 128 MB

function writeRequestBody(req, filePath) {
  return new Promise((resolve, reject) => {
    let bytes = 0;
    const stream = createWriteStream(filePath);
    req.on('data', (chunk) => {
      bytes += chunk.length;
      if (bytes > MAX_REQUEST_BODY) {
        req.destroy();
        stream.destroy();
        reject(Object.assign(new Error('Request body too large'), { statusCode: 413 }));
      }
    });
    req.on('error', reject);
    stream.on('error', reject);
    stream.on('finish', () => resolve(bytes));
    req.pipe(stream);
  });
}

async function writeJson(dataDir, subdir, fileName, data) {
  const dir = path.join(dataDir, subdir);
  await mkdir(dir, { recursive: true });
  await writeFile(path.join(dir, fileName), JSON.stringify(data, null, 2));
}

async function readStoredJson(dataDir, subdir, fileName) {
  try {
    const text = await readFile(path.join(dataDir, subdir, fileName), 'utf8');
    return JSON.parse(text);
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

function sendJson(res, statusCode, data) {
  res.statusCode = statusCode;
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(data));
}

async function assembleChunks({ chunksDir, outputPath }) {
  let names;
  try {
    names = (await readdir(chunksDir))
      .filter((name) => /^\d+\.part$/.test(name))
      .sort((a, b) => Number(a.split('.')[0]) - Number(b.split('.')[0]));
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw Object.assign(new Error('No chunks uploaded'), { statusCode: 409 });
    }
    throw error;
  }
  if (!names.length) {
    throw Object.assign(new Error('Upload has no completed chunks'), { statusCode: 409 });
  }
  const tmpPath = `${outputPath}.tmp`;
  const output = createWriteStream(tmpPath);
  for (const name of names) {
    const chunk = await readFile(path.join(chunksDir, name));
    output.write(chunk);
  }
  await new Promise((resolve, reject) => {
    output.end(resolve);
    output.on('error', reject);
  });
  await rename(tmpPath, outputPath);
}

async function runClipJob(dataDir, job, clipRunner) {
  const updatedJob = {
    ...job,
    status: 'running',
    progress: 0.5,
    updatedAt: new Date().toISOString(),
  };
  await writeJson(dataDir, 'jobs', `${job.cloudJobId}.json`, updatedJob);

  const media = await findMediaPackage(dataDir, job.cloudMediaId);
  const candidateById = new Map(
    (media?.clipCandidates ?? []).map((candidate) => [candidate.id, candidate]),
  );
  const clips = [];
  for (const [index, candidateId] of (job.candidateIds ?? []).entries()) {
    const candidate = candidateById.get(candidateId) ?? { id: candidateId };
    const fileName = `${safeFileName(candidateId)}.mp4`;
    const outputPath = path.join(dataDir, 'clips', job.cloudJobId, fileName);
    await mkdir(path.dirname(outputPath), { recursive: true });
    try {
      await clipRunner({
        dataDir,
        job,
        candidate,
        inputPath: await findOriginalObject(dataDir, job.cloudMediaId),
        outputPath,
      });
      clips.push({
        id: `clip_${candidateId}`,
        candidateId,
        index,
        status: 'completed',
        startMs: candidate.startMs ?? null,
        endMs: candidate.endMs ?? null,
        downloadPath: `/api/clip-jobs/${job.cloudJobId}/files/${fileName}`,
      });
    } catch (error) {
      log('clip.failed', {
        cloudJobId: job.cloudJobId,
        candidateId,
        error: error.message ?? String(error),
      });
      clips.push({
        id: `clip_${candidateId}`,
        candidateId,
        index,
        status: 'failed',
        error: error.message ?? String(error),
        startMs: candidate.startMs ?? null,
        endMs: candidate.endMs ?? null,
      });
    }
  }
  const jobStatus = clips.every((c) => c.status === 'completed') ? 'completed' : 'partial';
  const manifest = {
    schemaVersion: 1,
    cloudJobId: job.cloudJobId,
    cloudMediaId: job.cloudMediaId,
    status: jobStatus,
    clips,
    generatedAt: new Date().toISOString(),
  };
  await writeJson(dataDir, 'manifests', `${job.cloudJobId}.json`, manifest);
  const completedJob = {
    ...updatedJob,
    status: jobStatus,
    progress: 1,
    manifestPath: path.join(dataDir, 'manifests', `${job.cloudJobId}.json`),
    updatedAt: new Date().toISOString(),
  };
  await writeJson(dataDir, 'jobs', `${job.cloudJobId}.json`, completedJob);
  log('job.completed', {
    cloudJobId: job.cloudJobId,
    clipCount: clips.length,
  });
  return completedJob;
}

async function findMediaPackage(dataDir, cloudMediaId) {
  return readStoredJson(dataDir, 'media', `${cloudMediaId}.json`);
}

async function findOriginalObject(dataDir, cloudMediaId) {
  try {
    const files = await readdir(path.join(dataDir, 'objects', cloudMediaId));
    if (files.length === 0) return null;
    return path.join(dataDir, 'objects', cloudMediaId, files[0]);
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

async function defaultClipRunner({ inputPath, outputPath, candidate }) {
  if (!inputPath) {
    await writeFile(outputPath, Buffer.from(`placeholder:${candidate.id}`));
    return;
  }
  const ffmpegPath = process.env.FFMPEG_PATH ?? 'ffmpeg';
  const startMs = Number(candidate.startMs ?? 0);
  const endMs = Number(candidate.endMs ?? startMs + 60000);
  const durationMs = Math.max(1000, endMs - startMs);
  await runProcess(ffmpegPath, [
    '-y',
    '-ss',
    formatFfmpegTime(startMs),
    '-i',
    inputPath,
    '-t',
    formatFfmpegTime(durationMs),
    '-c',
    'copy',
    outputPath,
  ]);
}

function runProcess(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString('utf8');
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`ffmpeg exited with code ${code}: ${stderr.slice(-500)}`));
      }
    });
  });
}

function formatFfmpegTime(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const two = (value) => String(value).padStart(2, '0');
  return `${two(hours)}:${two(minutes)}:${two(seconds)}`;
}

function hashText(text) {
  return createHash('sha256').update(text).digest('hex');
}

function hashBuffer(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

function safeEqual(a, b) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

function safeFileName(value) {
  const name = path.basename(value).replace(/[^A-Za-z0-9_.-]+/g, '-');
  return name || 'original.bin';
}

function log(event, fields = {}) {
  console.log(JSON.stringify({ event, at: new Date().toISOString(), ...fields }));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = createServer(createApp());
  server.listen(DEFAULT_PORT, '0.0.0.0', () => {
    console.log(`edge-cloud-clips listening on ${DEFAULT_PORT}`);
  });
}

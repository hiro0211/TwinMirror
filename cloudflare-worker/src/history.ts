import { extractDeviceId, isPremiumHeader, jsonError } from "./auth";

export interface HistoryEnv {
  HISTORY_BUCKET: R2Bucket;
  HISTORY_DB: D1Database;
}

const FREE_LIMIT = 3;
const FREE_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;

interface HistoryRow {
  id: string;
  device_id: string;
  created_at: number;
  expires_at: number | null;
  gender: string | null;
  age: string | null;
  mode: string | null;
  style: string | null;
  ratio: string | null;
  prompt: string | null;
  r2_key: string;
  thumb_r2_key: string;
}

export async function saveHistory(
  request: Request,
  env: HistoryEnv,
): Promise<Response> {
  const deviceId = extractDeviceId(request);
  if (!deviceId) return jsonError(400, "invalid_device_id");

  let payload: Record<string, unknown>;
  try {
    payload = (await request.json()) as Record<string, unknown>;
  } catch {
    return jsonError(400, "invalid_json");
  }

  const imageB64 = payload.image;
  const thumbB64 = payload.thumbnail ?? payload.image;
  if (typeof imageB64 !== "string" || imageB64.length === 0) {
    return jsonError(400, "missing_image");
  }
  if (typeof thumbB64 !== "string" || thumbB64.length === 0) {
    return jsonError(400, "missing_thumbnail");
  }

  const imageBytes = decodeBase64(imageB64);
  const thumbBytes = decodeBase64(thumbB64);
  if (!imageBytes || !thumbBytes) return jsonError(400, "invalid_image_encoding");
  if (imageBytes.byteLength > MAX_IMAGE_BYTES) return jsonError(413, "image_too_large");

  const isPremium = isPremiumHeader(request);
  const now = Date.now();
  const id = crypto.randomUUID();
  const r2_key = `${deviceId}/${id}.jpg`;
  const thumb_r2_key = `${deviceId}/${id}_thumb.jpg`;
  const expiresAt = isPremium ? null : now + FREE_TTL_MS;

  await env.HISTORY_BUCKET.put(r2_key, imageBytes, {
    httpMetadata: { contentType: "image/jpeg" },
  });
  await env.HISTORY_BUCKET.put(thumb_r2_key, thumbBytes, {
    httpMetadata: { contentType: "image/jpeg" },
  });

  await env.HISTORY_DB.prepare(
    `INSERT INTO history
     (id, device_id, created_at, expires_at, gender, age, mode, style, ratio, prompt, r2_key, thumb_r2_key)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
  )
    .bind(
      id,
      deviceId,
      now,
      expiresAt,
      stringOrNull(payload.gender),
      stringOrNull(payload.age),
      stringOrNull(payload.mode),
      stringOrNull(payload.style),
      stringOrNull(payload.ratio),
      stringOrNull(payload.prompt),
      r2_key,
      thumb_r2_key,
    )
    .run();

  return new Response(
    JSON.stringify({
      id,
      createdAt: now,
      gender: payload.gender ?? null,
      age: payload.age ?? null,
      mode: payload.mode ?? null,
      style: payload.style ?? null,
      ratio: payload.ratio ?? null,
      prompt: payload.prompt ?? null,
    }),
    { status: 201, headers: { "Content-Type": "application/json" } },
  );
}

export async function listHistory(
  request: Request,
  env: HistoryEnv,
): Promise<Response> {
  const deviceId = extractDeviceId(request);
  if (!deviceId) return jsonError(400, "invalid_device_id");

  const isPremium = isPremiumHeader(request);
  const limit = isPremium ? 1000 : FREE_LIMIT;

  const result = await env.HISTORY_DB.prepare(
    `SELECT id, created_at, gender, age, mode, style, ratio, prompt
     FROM history
     WHERE device_id = ?
     ORDER BY created_at DESC
     LIMIT ?`,
  )
    .bind(deviceId, limit)
    .all<{
      id: string;
      created_at: number;
      gender: string | null;
      age: string | null;
      mode: string | null;
      style: string | null;
      ratio: string | null;
      prompt: string | null;
    }>();

  const totalRow = await env.HISTORY_DB.prepare(
    `SELECT COUNT(*) AS total FROM history WHERE device_id = ?`,
  )
    .bind(deviceId)
    .first<{ total: number }>();
  const totalCount = totalRow?.total ?? 0;

  const items = (result.results ?? []).map((row) => ({
    id: row.id,
    createdAt: row.created_at,
    gender: row.gender,
    age: row.age,
    mode: row.mode,
    style: row.style,
    ratio: row.ratio,
    prompt: row.prompt,
  }));

  return new Response(
    JSON.stringify({
      items,
      totalCount,
      freeLimitReached: !isPremium && totalCount > FREE_LIMIT,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

export async function getHistoryImage(
  request: Request,
  env: HistoryEnv,
  id: string,
): Promise<Response> {
  const deviceId = extractDeviceId(request);
  if (!deviceId) return jsonError(400, "invalid_device_id");

  const row = await fetchOwnedRow(env, id, deviceId);
  if (!row) return jsonError(404, "not_found");

  const variant = new URL(request.url).searchParams.get("variant");
  const key = variant === "thumb" ? row.thumb_r2_key : row.r2_key;
  const obj = await env.HISTORY_BUCKET.get(key);
  if (!obj) return jsonError(404, "image_missing");

  return new Response(obj.body, {
    status: 200,
    headers: { "Content-Type": "image/jpeg" },
  });
}

export async function deleteHistory(
  request: Request,
  env: HistoryEnv,
  id: string,
): Promise<Response> {
  const deviceId = extractDeviceId(request);
  if (!deviceId) return jsonError(400, "invalid_device_id");

  const row = await fetchOwnedRow(env, id, deviceId);
  if (!row) return jsonError(404, "not_found");

  await env.HISTORY_BUCKET.delete([row.r2_key, row.thumb_r2_key]);
  await env.HISTORY_DB.prepare(
    `DELETE FROM history WHERE id = ? AND device_id = ?`,
  )
    .bind(id, deviceId)
    .run();
  return new Response(null, { status: 204 });
}

export async function deleteAllHistory(
  request: Request,
  env: HistoryEnv,
): Promise<Response> {
  const deviceId = extractDeviceId(request);
  if (!deviceId) return jsonError(400, "invalid_device_id");

  const result = await env.HISTORY_DB.prepare(
    `SELECT r2_key, thumb_r2_key FROM history WHERE device_id = ?`,
  )
    .bind(deviceId)
    .all<{ r2_key: string; thumb_r2_key: string }>();

  const keys: string[] = [];
  for (const row of result.results ?? []) {
    keys.push(row.r2_key, row.thumb_r2_key);
  }
  if (keys.length > 0) {
    await env.HISTORY_BUCKET.delete(keys);
  }
  await env.HISTORY_DB.prepare(
    `DELETE FROM history WHERE device_id = ?`,
  )
    .bind(deviceId)
    .run();

  return new Response(null, { status: 204 });
}

export async function cleanupExpiredHistory(env: HistoryEnv): Promise<void> {
  const now = Date.now();
  const expired = await env.HISTORY_DB.prepare(
    `SELECT r2_key, thumb_r2_key FROM history
     WHERE expires_at IS NOT NULL AND expires_at < ?`,
  )
    .bind(now)
    .all<{ r2_key: string; thumb_r2_key: string }>();

  const keys: string[] = [];
  for (const row of expired.results ?? []) {
    keys.push(row.r2_key, row.thumb_r2_key);
  }
  if (keys.length > 0) {
    await env.HISTORY_BUCKET.delete(keys);
  }
  await env.HISTORY_DB.prepare(
    `DELETE FROM history WHERE expires_at IS NOT NULL AND expires_at < ?`,
  )
    .bind(now)
    .run();
}

async function fetchOwnedRow(
  env: HistoryEnv,
  id: string,
  deviceId: string,
): Promise<HistoryRow | null> {
  const row = await env.HISTORY_DB.prepare(
    `SELECT id, device_id, created_at, expires_at, gender, age, mode, style, ratio, prompt, r2_key, thumb_r2_key
     FROM history WHERE id = ? AND device_id = ?`,
  )
    .bind(id, deviceId)
    .first<HistoryRow>();
  return row ?? null;
}

function stringOrNull(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

function decodeBase64(s: string): Uint8Array | null {
  try {
    const binary = atob(s);
    const out = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
    return out;
  } catch {
    return null;
  }
}

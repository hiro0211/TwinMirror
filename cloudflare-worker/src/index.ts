import { checkAuthToken, jsonError } from "./auth";
import {
  cleanupExpiredHistory,
  deleteHistory,
  getHistoryImage,
  listHistory,
  saveHistory,
} from "./history";

export interface Env {
  GEMINI_API_KEY: string;
  WORKER_AUTH_TOKEN: string;
  HISTORY_BUCKET?: R2Bucket;
  HISTORY_DB?: D1Database;
}

const ALLOWED_MODELS = new Set([
  "gemini-3-pro-image-preview",
  "gemini-3.1-flash-image-preview",
  "gemini-2.5-flash-image",
]);

const MAX_BODY_BYTES = 8 * 1024 * 1024;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (!env.WORKER_AUTH_TOKEN) return jsonError(500, "server_misconfigured");

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (path === "/generate") {
      if (method !== "POST") return jsonError(404, "not_found");
      if (!checkAuthToken(request, env.WORKER_AUTH_TOKEN)) {
        return jsonError(401, "unauthorized");
      }
      return handleGenerate(request, env);
    }

    if (path === "/history") {
      if (!checkAuthToken(request, env.WORKER_AUTH_TOKEN)) {
        return jsonError(401, "unauthorized");
      }
      const historyEnv = requireHistoryEnv(env);
      if (!historyEnv) return jsonError(500, "history_not_configured");
      if (method === "POST") return saveHistory(request, historyEnv);
      if (method === "GET") return listHistory(request, historyEnv);
      return jsonError(405, "method_not_allowed");
    }

    const imageMatch = path.match(/^\/history\/([^/]+)\/image$/);
    if (imageMatch) {
      if (method !== "GET") return jsonError(404, "not_found");
      if (!checkAuthToken(request, env.WORKER_AUTH_TOKEN)) {
        return jsonError(401, "unauthorized");
      }
      const historyEnv = requireHistoryEnv(env);
      if (!historyEnv) return jsonError(500, "history_not_configured");
      return getHistoryImage(request, historyEnv, imageMatch[1]);
    }

    const itemMatch = path.match(/^\/history\/([^/]+)$/);
    if (itemMatch) {
      if (method !== "DELETE") return jsonError(404, "not_found");
      if (!checkAuthToken(request, env.WORKER_AUTH_TOKEN)) {
        return jsonError(401, "unauthorized");
      }
      const historyEnv = requireHistoryEnv(env);
      if (!historyEnv) return jsonError(500, "history_not_configured");
      return deleteHistory(request, historyEnv, itemMatch[1]);
    }

    return jsonError(404, "not_found");
  },

  async scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    const historyEnv = requireHistoryEnv(env);
    if (historyEnv) {
      ctx.waitUntil(cleanupExpiredHistory(historyEnv));
    }
  },
} satisfies ExportedHandler<Env>;

function requireHistoryEnv(env: Env) {
  if (!env.HISTORY_BUCKET || !env.HISTORY_DB) return null;
  return { HISTORY_BUCKET: env.HISTORY_BUCKET, HISTORY_DB: env.HISTORY_DB };
}

async function handleGenerate(request: Request, env: Env): Promise<Response> {
  if (!env.GEMINI_API_KEY) {
    return jsonError(500, "server_misconfigured");
  }

  const contentLength = Number(request.headers.get("Content-Length") ?? "0");
  if (contentLength > MAX_BODY_BYTES) {
    return jsonError(413, "payload_too_large");
  }

  let payload: Record<string, unknown>;
  try {
    payload = (await request.json()) as Record<string, unknown>;
  } catch {
    return jsonError(400, "invalid_json");
  }

  const model = payload.model;
  if (typeof model !== "string" || !ALLOWED_MODELS.has(model)) {
    return jsonError(400, "model_not_allowed");
  }

  const { model: _drop, ...forwardedBody } = payload;

  const upstreamUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const upstreamResponse = await fetch(upstreamUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": env.GEMINI_API_KEY,
    },
    body: JSON.stringify(forwardedBody),
  });

  const responseHeaders = new Headers();
  const ct = upstreamResponse.headers.get("Content-Type");
  if (ct) responseHeaders.set("Content-Type", ct);
  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    headers: responseHeaders,
  });
}

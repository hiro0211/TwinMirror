export interface Env {
  GEMINI_API_KEY: string;
  WORKER_AUTH_TOKEN: string;
}

const ALLOWED_MODELS = new Set([
  "gemini-3.1-flash-image-preview",
  "gemini-2.5-flash-image",
]);

const MAX_BODY_BYTES = 8 * 1024 * 1024;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST" || new URL(request.url).pathname !== "/generate") {
      return jsonError(404, "not_found");
    }

    if (!env.GEMINI_API_KEY || !env.WORKER_AUTH_TOKEN) {
      return jsonError(500, "server_misconfigured");
    }

    const presented = request.headers.get("X-Auth-Token") ?? "";
    if (!constantTimeEqual(presented, env.WORKER_AUTH_TOKEN)) {
      return jsonError(401, "unauthorized");
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
  },
} satisfies ExportedHandler<Env>;

function jsonError(status: number, code: string): Response {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

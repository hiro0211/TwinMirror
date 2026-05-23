const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function checkAuthToken(request: Request, expected: string): boolean {
  const presented = request.headers.get("X-Auth-Token") ?? "";
  return constantTimeEqual(presented, expected);
}

export function extractDeviceId(request: Request): string | null {
  const raw = request.headers.get("X-Device-Id");
  if (!raw) return null;
  if (!UUID_RE.test(raw)) return null;
  return raw.toLowerCase();
}

export function isPremiumHeader(request: Request): boolean {
  return (request.headers.get("X-Is-Premium") ?? "").toLowerCase() === "true";
}

export function jsonError(status: number, code: string): Response {
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

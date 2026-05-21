import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import worker, { type Env } from "../src/index";

const TEST_ENV: Env = {
  GEMINI_API_KEY: "test-gemini-key",
  WORKER_AUTH_TOKEN: "test-auth-token",
};

const validBody = {
  model: "gemini-2.5-flash-image",
  contents: [{ parts: [{ text: "hi" }] }],
  generationConfig: { responseModalities: ["IMAGE"] },
};

function geminiSuccessResponse(): Response {
  return new Response(
    JSON.stringify({
      candidates: [
        {
          content: {
            parts: [
              { inline_data: { mime_type: "image/png", data: "AAA=" } },
            ],
          },
          finishReason: "STOP",
        },
      ],
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

async function call(req: Request, env: Env = TEST_ENV): Promise<Response> {
  return worker.fetch(req, env);
}

describe("twinmirror-gemini-proxy", () => {
  let fetchSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    fetchSpy = vi.spyOn(globalThis, "fetch");
  });

  afterEach(() => {
    fetchSpy.mockRestore();
  });

  it("returns 404 for non-POST methods", async () => {
    const res = await call(new Request("https://w/generate", { method: "GET" }));
    expect(res.status).toBe(404);
  });

  it("returns 404 for unknown paths", async () => {
    const res = await call(
      new Request("https://w/other", {
        method: "POST",
        headers: { "X-Auth-Token": TEST_ENV.WORKER_AUTH_TOKEN },
      }),
    );
    expect(res.status).toBe(404);
  });

  it("returns 401 when X-Auth-Token is missing", async () => {
    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        body: JSON.stringify(validBody),
      }),
    );
    expect(res.status).toBe(401);
  });

  it("returns 401 when X-Auth-Token is wrong", async () => {
    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        headers: { "X-Auth-Token": "wrong" },
        body: JSON.stringify(validBody),
      }),
    );
    expect(res.status).toBe(401);
  });

  it("returns 400 when JSON is invalid", async () => {
    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        headers: {
          "X-Auth-Token": TEST_ENV.WORKER_AUTH_TOKEN,
          "Content-Type": "application/json",
        },
        body: "{not json",
      }),
    );
    expect(res.status).toBe(400);
  });

  it("returns 400 when model is not in allowlist", async () => {
    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        headers: {
          "X-Auth-Token": TEST_ENV.WORKER_AUTH_TOKEN,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ...validBody, model: "gpt-5" }),
      }),
    );
    expect(res.status).toBe(400);
  });

  it("returns 500 when GEMINI_API_KEY is missing", async () => {
    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        headers: {
          "X-Auth-Token": TEST_ENV.WORKER_AUTH_TOKEN,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(validBody),
      }),
      { GEMINI_API_KEY: "", WORKER_AUTH_TOKEN: TEST_ENV.WORKER_AUTH_TOKEN },
    );
    expect(res.status).toBe(500);
  });

  it("forwards request to Gemini with correct URL, headers, and body (model stripped)", async () => {
    fetchSpy.mockResolvedValueOnce(geminiSuccessResponse());

    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        headers: {
          "X-Auth-Token": TEST_ENV.WORKER_AUTH_TOKEN,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(validBody),
      }),
    );

    expect(res.status).toBe(200);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [calledUrl, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(calledUrl).toBe(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent",
    );
    expect((init.headers as Record<string, string>)["x-goog-api-key"]).toBe(
      TEST_ENV.GEMINI_API_KEY,
    );
    const forwarded = JSON.parse(init.body as string);
    expect(forwarded.model).toBeUndefined();
    expect(forwarded.contents).toEqual(validBody.contents);
    expect(forwarded.generationConfig).toEqual(validBody.generationConfig);
  });

  it("passes through Gemini status and JSON body", async () => {
    const upstream = new Response(
      JSON.stringify({ error: { code: 429, message: "quota" } }),
      { status: 429, headers: { "Content-Type": "application/json" } },
    );
    fetchSpy.mockResolvedValueOnce(upstream);

    const res = await call(
      new Request("https://w/generate", {
        method: "POST",
        headers: {
          "X-Auth-Token": TEST_ENV.WORKER_AUTH_TOKEN,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(validBody),
      }),
    );

    expect(res.status).toBe(429);
    const body = await res.json();
    expect(body).toEqual({ error: { code: 429, message: "quota" } });
  });
});

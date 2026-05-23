import { describe, it, expect, beforeEach } from "vitest";
import worker, { type Env } from "../src/index";
import { createMockD1, createMockR2 } from "./helpers/mocks";

const AUTH = "test-auth-token";
const DEVICE_A = "11111111-1111-4111-8111-111111111111";
const DEVICE_B = "22222222-2222-4222-8222-222222222222";

function makeEnv(): Env {
  return {
    GEMINI_API_KEY: "test-gemini-key",
    WORKER_AUTH_TOKEN: AUTH,
    HISTORY_BUCKET: createMockR2(),
    HISTORY_DB: createMockD1(),
  };
}

function tinyJpegBase64(): string {
  // valid JPEG SOI + EOI markers; not a real image but enough for byte-roundtrip tests
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

function savePayload(overrides: Record<string, unknown> = {}) {
  return {
    image: tinyJpegBase64(),
    thumbnail: tinyJpegBase64(),
    gender: "female",
    age: "5",
    mode: "premium",
    style: "photorealistic",
    ratio: "50_50",
    prompt: "a smiling child",
    ...overrides,
  };
}

async function postHistory(
  env: Env,
  body: unknown,
  headers: Record<string, string> = {
    "X-Auth-Token": AUTH,
    "X-Device-Id": DEVICE_A,
    "Content-Type": "application/json",
  },
): Promise<Response> {
  return worker.fetch(
    new Request("https://w/history", {
      method: "POST",
      headers,
      body: typeof body === "string" ? body : JSON.stringify(body),
    }),
    env,
  );
}

async function listHistory(
  env: Env,
  query = "",
  headers: Record<string, string> = {
    "X-Auth-Token": AUTH,
    "X-Device-Id": DEVICE_A,
    "X-Is-Premium": "false",
  },
): Promise<Response> {
  return worker.fetch(
    new Request(`https://w/history${query}`, { method: "GET", headers }),
    env,
  );
}

async function seedItems(env: Env, count: number, device: string): Promise<string[]> {
  const ids: string[] = [];
  for (let i = 0; i < count; i++) {
    const res = await postHistory(env, savePayload({ prompt: `item-${i}` }), {
      "X-Auth-Token": AUTH,
      "X-Device-Id": device,
      "Content-Type": "application/json",
    });
    expect(res.status).toBe(201);
    const body = (await res.json()) as { id: string };
    ids.push(body.id);
    // ensure stable ordering by created_at
    await new Promise((r) => setTimeout(r, 2));
  }
  return ids;
}

describe("history endpoints", () => {
  let env: Env;
  beforeEach(() => {
    env = makeEnv();
  });

  describe("auth", () => {
    it("returns 401 without X-Auth-Token", async () => {
      const res = await postHistory(env, savePayload(), {
        "X-Device-Id": DEVICE_A,
        "Content-Type": "application/json",
      });
      expect(res.status).toBe(401);
    });

    it("returns 401 with wrong X-Auth-Token", async () => {
      const res = await postHistory(env, savePayload(), {
        "X-Auth-Token": "wrong",
        "X-Device-Id": DEVICE_A,
        "Content-Type": "application/json",
      });
      expect(res.status).toBe(401);
    });

    it("returns 400 without X-Device-Id", async () => {
      const res = await postHistory(env, savePayload(), {
        "X-Auth-Token": AUTH,
        "Content-Type": "application/json",
      });
      expect(res.status).toBe(400);
    });

    it("returns 400 with malformed X-Device-Id", async () => {
      const res = await postHistory(env, savePayload(), {
        "X-Auth-Token": AUTH,
        "X-Device-Id": "not-a-uuid",
        "Content-Type": "application/json",
      });
      expect(res.status).toBe(400);
    });
  });

  describe("POST /history", () => {
    it("returns 400 when image is missing", async () => {
      const res = await postHistory(env, { ...savePayload(), image: undefined });
      expect(res.status).toBe(400);
    });

    it("returns 400 when JSON is malformed", async () => {
      const res = await postHistory(env, "{not json");
      expect(res.status).toBe(400);
    });

    it("returns 201 and a record with id + createdAt on success", async () => {
      const res = await postHistory(env, savePayload());
      expect(res.status).toBe(201);
      const body = (await res.json()) as Record<string, unknown>;
      expect(typeof body.id).toBe("string");
      expect(typeof body.createdAt).toBe("number");
      expect(body.gender).toBe("female");
      expect(body.prompt).toBe("a smiling child");
    });

    it("stores the image bytes in R2 so they can be fetched back", async () => {
      const save = await postHistory(env, savePayload());
      const { id } = (await save.json()) as { id: string };

      const img = await worker.fetch(
        new Request(`https://w/history/${id}/image`, {
          method: "GET",
          headers: { "X-Auth-Token": AUTH, "X-Device-Id": DEVICE_A },
        }),
        env,
      );
      expect(img.status).toBe(200);
      expect(img.headers.get("Content-Type")).toBe("image/jpeg");
      const bytes = new Uint8Array(await img.arrayBuffer());
      expect(bytes.length).toBeGreaterThan(0);
    });
  });

  describe("GET /history (free user gating)", () => {
    it("returns at most 3 items for free users even with 5 saved", async () => {
      await seedItems(env, 5, DEVICE_A);
      const res = await listHistory(env);
      expect(res.status).toBe(200);
      const body = (await res.json()) as { items: unknown[]; freeLimitReached: boolean };
      expect(body.items.length).toBe(3);
      expect(body.freeLimitReached).toBe(true);
    });

    it("returns all items for premium users", async () => {
      await seedItems(env, 5, DEVICE_A);
      const res = await listHistory(env, "", {
        "X-Auth-Token": AUTH,
        "X-Device-Id": DEVICE_A,
        "X-Is-Premium": "true",
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { items: unknown[]; freeLimitReached: boolean };
      expect(body.items.length).toBe(5);
      expect(body.freeLimitReached).toBe(false);
    });

    it("sorts items newest-first", async () => {
      const ids = await seedItems(env, 3, DEVICE_A);
      const res = await listHistory(env);
      const body = (await res.json()) as { items: { id: string }[] };
      expect(body.items.map((i) => i.id)).toEqual([...ids].reverse());
    });

    it("never reveals another device's items", async () => {
      await seedItems(env, 2, DEVICE_A);
      const res = await listHistory(env, "", {
        "X-Auth-Token": AUTH,
        "X-Device-Id": DEVICE_B,
        "X-Is-Premium": "true",
      });
      const body = (await res.json()) as { items: unknown[] };
      expect(body.items).toEqual([]);
    });

    it("includes totalCount so client can show '+N more behind paywall'", async () => {
      await seedItems(env, 5, DEVICE_A);
      const res = await listHistory(env);
      const body = (await res.json()) as { totalCount: number };
      expect(body.totalCount).toBe(5);
    });
  });

  describe("GET /history/:id/image", () => {
    it("returns 404 when the image belongs to another device", async () => {
      const save = await postHistory(env, savePayload());
      const { id } = (await save.json()) as { id: string };
      const res = await worker.fetch(
        new Request(`https://w/history/${id}/image`, {
          method: "GET",
          headers: { "X-Auth-Token": AUTH, "X-Device-Id": DEVICE_B },
        }),
        env,
      );
      expect(res.status).toBe(404);
    });

    it("returns 404 for unknown id", async () => {
      const res = await worker.fetch(
        new Request(`https://w/history/does-not-exist/image`, {
          method: "GET",
          headers: { "X-Auth-Token": AUTH, "X-Device-Id": DEVICE_A },
        }),
        env,
      );
      expect(res.status).toBe(404);
    });

    it("serves the thumbnail when ?variant=thumb", async () => {
      const save = await postHistory(env, savePayload());
      const { id } = (await save.json()) as { id: string };
      const res = await worker.fetch(
        new Request(`https://w/history/${id}/image?variant=thumb`, {
          method: "GET",
          headers: { "X-Auth-Token": AUTH, "X-Device-Id": DEVICE_A },
        }),
        env,
      );
      expect(res.status).toBe(200);
    });
  });

  describe("DELETE /history/:id", () => {
    it("removes the item and its R2 objects", async () => {
      const save = await postHistory(env, savePayload());
      const { id } = (await save.json()) as { id: string };

      const del = await worker.fetch(
        new Request(`https://w/history/${id}`, {
          method: "DELETE",
          headers: { "X-Auth-Token": AUTH, "X-Device-Id": DEVICE_A },
        }),
        env,
      );
      expect(del.status).toBe(204);

      const list = await listHistory(env);
      const body = (await list.json()) as { items: unknown[] };
      expect(body.items).toEqual([]);
    });

    it("returns 404 when deleting another device's item", async () => {
      const save = await postHistory(env, savePayload());
      const { id } = (await save.json()) as { id: string };

      const del = await worker.fetch(
        new Request(`https://w/history/${id}`, {
          method: "DELETE",
          headers: { "X-Auth-Token": AUTH, "X-Device-Id": DEVICE_B },
        }),
        env,
      );
      expect(del.status).toBe(404);
    });
  });

  describe("scheduled() — TTL cleanup", () => {
    it("removes only items past their expires_at", async () => {
      // seed two; manually mutate expires_at so one is expired
      const ids = await seedItems(env, 2, DEVICE_A);
      const db = env.HISTORY_DB as ReturnType<typeof createMockD1>;
      // force first item to be expired (1 ms past epoch)
      db._setExpires(ids[0], 1);

      const ctx = { waitUntil: (_p: Promise<unknown>) => {} } as ExecutionContext;
      await worker.scheduled!(
        { scheduledTime: Date.now(), cron: "0 3 * * *" } as ScheduledController,
        env,
        ctx,
      );

      const list = await listHistory(env, "", {
        "X-Auth-Token": AUTH,
        "X-Device-Id": DEVICE_A,
        "X-Is-Premium": "true",
      });
      const body = (await list.json()) as { items: { id: string }[] };
      const remaining = body.items.map((i) => i.id);
      expect(remaining).not.toContain(ids[0]);
      expect(remaining).toContain(ids[1]);
    });
  });
});

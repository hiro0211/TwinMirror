/**
 * Minimal in-memory mocks for the subset of R2 / D1 APIs used by `src/history.ts`.
 *
 * D1 supports only the exact SQL statements the worker issues. The parser is a
 * naive regex match on the leading keywords — keep the worker's SQL in lockstep
 * with the patterns below.
 */

type D1Row = Record<string, unknown>;

export interface MockD1 extends D1Database {
  _rows(): D1Row[];
  _setExpires(id: string, expiresAt: number): void;
  _now(): number;
}

export function createMockD1(): MockD1 {
  const rows: D1Row[] = [];

  const prepare = (sql: string): D1PreparedStatement => {
    const args: unknown[] = [];
    const stmt: D1PreparedStatement = {
      bind(...values: unknown[]) {
        args.push(...values);
        return stmt;
      },
      async run() {
        execute(sql.trim(), args);
        return { success: true, meta: {} } as D1Result;
      },
      async first<T = D1Row>() {
        const result = execute(sql.trim(), args) as D1Row[];
        return (result[0] as T) ?? null;
      },
      async all<T = D1Row>() {
        const result = execute(sql.trim(), args) as D1Row[];
        return { results: result as T[], success: true, meta: {} } as D1Result<T>;
      },
      async raw() {
        return [] as unknown[];
      },
    } as unknown as D1PreparedStatement;
    return stmt;
  };

  function execute(sql: string, args: unknown[]): D1Row[] {
    const lower = sql.toLowerCase();
    if (lower.startsWith("insert into history")) {
      // INSERT INTO history (id, device_id, created_at, expires_at, gender, age, mode, style, ratio, prompt, r2_key, thumb_r2_key) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
      const [id, device_id, created_at, expires_at, gender, age, mode, style, ratio, prompt, r2_key, thumb_r2_key] =
        args;
      rows.push({
        id,
        device_id,
        created_at,
        expires_at,
        gender,
        age,
        mode,
        style,
        ratio,
        prompt,
        r2_key,
        thumb_r2_key,
      });
      return [];
    }
    if (lower.startsWith("select") && lower.includes("from history") && lower.includes("where id = ?")) {
      const [id, device_id] = args;
      return rows.filter(
        (r) =>
          r.id === id &&
          (device_id === undefined || r.device_id === device_id),
      );
    }
    if (lower.startsWith("select") && lower.includes("count(")) {
      // SELECT COUNT(*) AS total FROM history WHERE device_id = ?
      const [device_id] = args;
      const total = rows.filter((r) => r.device_id === device_id).length;
      return [{ total }];
    }
    if (lower.startsWith("select") && lower.includes("from history")) {
      // SELECT ... FROM history WHERE device_id = ? ORDER BY created_at DESC LIMIT ?
      const [device_id, limit] = args;
      const filtered = rows
        .filter((r) => r.device_id === device_id)
        .sort((a, b) => (b.created_at as number) - (a.created_at as number));
      if (typeof limit === "number") return filtered.slice(0, limit);
      return filtered;
    }
    if (lower.startsWith("delete from history") && lower.includes("expires_at")) {
      // DELETE FROM history WHERE expires_at IS NOT NULL AND expires_at < ?
      const [now] = args as [number];
      const survivors: D1Row[] = [];
      const removed: D1Row[] = [];
      for (const r of rows) {
        if (r.expires_at != null && (r.expires_at as number) < now) removed.push(r);
        else survivors.push(r);
      }
      rows.length = 0;
      rows.push(...survivors);
      return removed;
    }
    if (lower.startsWith("delete from history")) {
      // DELETE FROM history WHERE id = ? AND device_id = ?
      const [id, device_id] = args;
      const survivors: D1Row[] = [];
      let removedCount = 0;
      for (const r of rows) {
        if (r.id === id && r.device_id === device_id) {
          removedCount++;
        } else {
          survivors.push(r);
        }
      }
      rows.length = 0;
      rows.push(...survivors);
      return Array(removedCount).fill({ deleted: 1 });
    }
    throw new Error(`MockD1: unsupported SQL: ${sql}`);
  }

  const db = {
    prepare,
    async batch(stmts: D1PreparedStatement[]) {
      const results: D1Result[] = [];
      for (const s of stmts) results.push(await s.run());
      return results;
    },
    async exec(_sql: string) {
      return { count: 0, duration: 0 } as D1ExecResult;
    },
    dump() {
      return Promise.resolve(new ArrayBuffer(0));
    },
    withSession() {
      return db as unknown as D1DatabaseSession;
    },
    _rows: () => rows,
    _setExpires(id: string, expiresAt: number) {
      const row = rows.find((r) => r.id === id);
      if (row) row.expires_at = expiresAt;
    },
    _now: () => Date.now(),
  };

  return db as unknown as MockD1;
}

export function createMockR2(): R2Bucket {
  const store = new Map<string, ArrayBuffer>();

  return {
    async put(key: string, value: ReadableStream | ArrayBuffer | ArrayBufferView | string | Blob | null) {
      const buf = await toArrayBuffer(value);
      store.set(key, buf);
      return { key } as unknown as R2Object;
    },
    async get(key: string) {
      const buf = store.get(key);
      if (!buf) return null;
      return {
        key,
        async arrayBuffer() {
          return buf;
        },
        body: new Response(buf).body!,
        size: buf.byteLength,
        httpMetadata: {},
      } as unknown as R2ObjectBody;
    },
    async delete(keys: string | string[]) {
      const list = Array.isArray(keys) ? keys : [keys];
      for (const k of list) store.delete(k);
    },
    async head(key: string) {
      return store.has(key) ? ({ key } as unknown as R2Object) : null;
    },
    async list() {
      return {
        objects: Array.from(store.keys()).map((k) => ({ key: k } as unknown as R2Object)),
        truncated: false,
      } as unknown as R2Objects;
    },
    async createMultipartUpload() {
      throw new Error("not implemented");
    },
    async resumeMultipartUpload() {
      throw new Error("not implemented");
    },
  } as unknown as R2Bucket;
}

async function toArrayBuffer(
  value: ReadableStream | ArrayBuffer | ArrayBufferView | string | Blob | null,
): Promise<ArrayBuffer> {
  if (value == null) return new ArrayBuffer(0);
  if (typeof value === "string") return new TextEncoder().encode(value).buffer as ArrayBuffer;
  if (value instanceof ArrayBuffer) return value;
  if (ArrayBuffer.isView(value))
    return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer;
  if (value instanceof Blob) return await value.arrayBuffer();
  // ReadableStream
  const res = new Response(value);
  return await res.arrayBuffer();
}

/**
 * courses / course-pars KV 스키마 헬퍼
 *
 * KV 키 구조:
 *   courses:current          — 최신 courses 메타 JSON
 *   courses:current:etag     — 최신 ETag 문자열
 *   courses:v:<version>      — 버전별 히스토리 (최근 4개 보존)
 *   course-pars:current
 *   course-pars:current:etag
 *   course-pars:v:<version>
 *   sync-meta                — cron 성공/실패 정보
 */

export type DatasetKey = "courses" | "course-pars";

export interface DatasetPayload {
  version: string;           // "YYYY-MM-DD"
  updatedAt: string;         // ISO 8601 UTC
  schema: number;            // 1
  count: number;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  [key: string]: any;        // courses: [...] 또는 coursePars: [...]
}

export interface SyncMeta {
  lastSuccessAt: string | null;
  lastFailureAt: string | null;
  successCount: number;
  failureCount: number;
  lastError?: string;
}

/** KV에서 현재 데이터셋 + ETag 읽기 */
export async function readCurrent(
  kv: KVNamespace,
  dataset: DatasetKey
): Promise<{ data: DatasetPayload | null; etag: string | null }> {
  const [raw, etag] = await Promise.all([
    kv.get(`${dataset}:current`),
    kv.get(`${dataset}:current:etag`),
  ]);
  if (!raw) return { data: null, etag: null };
  try {
    return { data: JSON.parse(raw) as DatasetPayload, etag };
  } catch {
    return { data: null, etag: null };
  }
}

/** KV에 새 버전 저장 + 최근 4개 이외 삭제 */
export async function writeCurrent(
  kv: KVNamespace,
  dataset: DatasetKey,
  payload: DatasetPayload
): Promise<string> {
  const raw = JSON.stringify(payload);

  // ETag: SHA-256의 앞 16바이트 (hex) — Web Crypto API (V8 환경)
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(raw)
  );
  const etag = `"${Array.from(new Uint8Array(digest))
    .slice(0, 16)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")}"`;

  const versionKey = `${dataset}:v:${payload.version}`;

  await Promise.all([
    kv.put(`${dataset}:current`, raw),
    kv.put(`${dataset}:current:etag`, etag),
    kv.put(versionKey, raw),
  ]);

  // 버전 히스토리 4개 초과분 삭제
  await pruneVersionHistory(kv, dataset, 4);

  return etag;
}

/** 버전 히스토리를 최근 N개로 제한 */
async function pruneVersionHistory(
  kv: KVNamespace,
  dataset: DatasetKey,
  keep: number
): Promise<void> {
  const prefix = `${dataset}:v:`;
  const list = await kv.list({ prefix });
  const keys = list.keys.map((k) => k.name).sort(); // 날짜 오름차순
  const toDelete = keys.slice(0, Math.max(0, keys.length - keep));
  await Promise.all(toDelete.map((k) => kv.delete(k)));
}

/** sync-meta 읽기 */
export async function readSyncMeta(kv: KVNamespace): Promise<SyncMeta> {
  const raw = await kv.get("sync-meta");
  if (!raw) {
    return {
      lastSuccessAt: null,
      lastFailureAt: null,
      successCount: 0,
      failureCount: 0,
    };
  }
  try {
    return JSON.parse(raw) as SyncMeta;
  } catch {
    return {
      lastSuccessAt: null,
      lastFailureAt: null,
      successCount: 0,
      failureCount: 0,
    };
  }
}

/** sync-meta 갱신 */
export async function writeSyncMeta(
  kv: KVNamespace,
  patch: Partial<SyncMeta>
): Promise<void> {
  const current = await readSyncMeta(kv);
  const updated: SyncMeta = { ...current, ...patch };
  await kv.put("sync-meta", JSON.stringify(updated));
}

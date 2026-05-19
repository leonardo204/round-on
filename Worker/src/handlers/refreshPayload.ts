/**
 * POST /v1/courses/refresh-payload
 *
 * GitHub Action이 골프존 fetch 완료 후 payload를 직접 전달하는 엔드포인트.
 * (Cloudflare Workers Free 50 subrequest 제한 우회)
 *
 * 인증: HMAC-SHA256 (기존 REFRESH_HMAC_SECRET 재사용)
 *   X-Signature: hmac-sha256=<hex>
 *   서명 대상: `${timestamp}:${nonce}`
 *
 * 중복 방지: nonce KV 5분 저장
 *
 * body JSON:
 *   {
 *     timestamp: string,           // ISO 8601 UTC
 *     nonce: string,               // hex 랜덤 16바이트
 *     courses: RefreshCourseEntry[],
 *     summary: { totalGolfzonCourses, matched, unmatched }
 *   }
 */

import type { Env } from "../types.js";
import {
  writeCurrent,
  writeSyncMeta,
  readSyncMeta,
  type DatasetPayload,
} from "../lib/coursesKv.js";
import { errorResponse, jsonResponse } from "../middleware/security.js";

const NONCE_PREFIX = "refresh-payload-nonce:";
const NONCE_TTL_SECONDS = 300;      // 5분
const TIMESTAMP_SLACK_MS = 300_000; // 5분

// ─── 타입 정의 ────────────────────────────────────────────────────────────────

interface RefreshSubCourse {
  name: string;
  pars: number[];
}

interface RefreshCourseEntry {
  courseId: string;
  courseName: string;
  source: string;
  confidence: string;
  subCourses: RefreshSubCourse[];
}

interface RefreshSummary {
  totalGolfzonCourses: number;
  matched: number;
  unmatched: number;
}

interface RefreshPayloadBody {
  timestamp: string;
  nonce: string;
  courses: RefreshCourseEntry[];
  summary?: RefreshSummary;
}

// ─── HMAC 검증 (refreshCourses.ts와 동일 로직) ───────────────────────────────

async function verifyHmac(
  secret: string,
  message: string,
  signature: string
): Promise<boolean> {
  const prefix = "hmac-sha256=";
  if (!signature.startsWith(prefix)) return false;
  const expectedHex = signature.slice(prefix.length);

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const sigBytes = hexToBytes(expectedHex);
  if (!sigBytes) return false;

  return crypto.subtle.verify(
    "HMAC",
    key,
    sigBytes.buffer as ArrayBuffer,
    enc.encode(message)
  );
}

function hexToBytes(hex: string): Uint8Array | null {
  if (hex.length % 2 !== 0) return null;
  const arr = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    const byte = parseInt(hex.slice(i, i + 2), 16);
    if (isNaN(byte)) return null;
    arr[i / 2] = byte;
  }
  return arr;
}

// ─── Telegram 알림 ───────────────────────────────────────────────────────────

async function sendTelegram(
  botToken: string,
  chatId: string,
  text: string
): Promise<void> {
  try {
    await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
  } catch (e) {
    console.error("[refreshPayload] Telegram 전송 실패:", e);
  }
}

// ─── 메인 핸들러 ─────────────────────────────────────────────────────────────

export async function handleRefreshPayload(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  // 1. 시크릿 확인
  const secret = env.REFRESH_HMAC_SECRET;
  if (!secret) {
    return errorResponse("INTERNAL_ERROR", "서버 설정 오류입니다.", 500);
  }

  // 2. 서명 헤더 확인
  const sigHeader = request.headers.get("X-Signature");
  if (!sigHeader) {
    return errorResponse("UNAUTHORIZED", "X-Signature 헤더가 필요합니다.", 401);
  }

  // 3. body 파싱
  let body: RefreshPayloadBody;
  try {
    body = (await request.json()) as RefreshPayloadBody;
  } catch {
    return errorResponse("VALIDATION_ERROR", "요청 body가 올바른 JSON이 아닙니다.", 400);
  }

  const { timestamp, nonce, courses, summary } = body;

  if (!timestamp || !nonce || !Array.isArray(courses)) {
    return errorResponse(
      "VALIDATION_ERROR",
      "timestamp, nonce, courses 필드가 필요합니다.",
      400
    );
  }

  // 4. 타임스탬프 유효성 (5분 이내)
  const ts = new Date(timestamp).getTime();
  if (isNaN(ts) || Math.abs(Date.now() - ts) > TIMESTAMP_SLACK_MS) {
    return errorResponse(
      "VALIDATION_ERROR",
      "타임스탬프가 유효하지 않거나 만료되었습니다.",
      400
    );
  }

  // 5. HMAC 검증
  const message = `${timestamp}:${nonce}`;
  const valid = await verifyHmac(secret, message, sigHeader);
  if (!valid) {
    return errorResponse("UNAUTHORIZED", "서명이 유효하지 않습니다.", 401);
  }

  // 6. nonce 중복 방지
  const nonceKey = `${NONCE_PREFIX}${nonce}`;
  const existing = await env.KV_COURSES.get(nonceKey);
  if (existing) {
    return errorResponse("VALIDATION_ERROR", "이미 처리된 요청입니다 (nonce 중복).", 409);
  }
  await env.KV_COURSES.put(nonceKey, "1", { expirationTtl: NONCE_TTL_SECONDS });

  // 7. KV 저장 (waitUntil — 즉시 202 반환)
  ctx.waitUntil(applyPayload(env, timestamp, courses, summary));

  const matched = courses.length;
  return jsonResponse(
    {
      ok: true,
      message: "코스 페이로드를 수신하여 KV 갱신을 시작합니다.",
      courses: matched,
      summary: summary ?? null,
    },
    202
  );
}

// ─── KV 갱신 ─────────────────────────────────────────────────────────────────

async function applyPayload(
  env: Env,
  timestamp: string,
  courses: RefreshCourseEntry[],
  summary?: RefreshSummary
): Promise<void> {
  const now = timestamp;
  const version = now.slice(0, 10); // "YYYY-MM-DD"

  try {
    console.log(`[refreshPayload] KV 갱신 시작 version=${version} courses=${courses.length}`);

    // courses:current — courseId/courseName 목록 (우리 DB 호환 최소 메타)
    const coursesMeta = courses.map((c) => ({
      id: c.courseId,
      name: c.courseName,
    }));

    const coursesPayload: DatasetPayload = {
      version,
      updatedAt: now,
      schema: 1,
      count: coursesMeta.length,
      courses: coursesMeta,
    };

    // course-pars:current — courseId별 subCourses pars
    const courseParsEntries = courses.map((c) => ({
      courseId: c.courseId,
      courseName: c.courseName,
      subCourses: c.subCourses,
    }));

    const courseParsPayload: DatasetPayload = {
      version,
      updatedAt: now,
      schema: 1,
      count: courseParsEntries.length,
      coursePars: courseParsEntries,
    };

    // KV 병렬 저장
    await Promise.all([
      writeCurrent(env.KV_COURSES, "courses", coursesPayload),
      writeCurrent(env.KV_COURSES, "course-pars", courseParsPayload),
    ]);

    // sync-meta 갱신
    const meta = await readSyncMeta(env.KV_COURSES);
    await writeSyncMeta(env.KV_COURSES, {
      lastSuccessAt: now,
      successCount: (meta.successCount ?? 0) + 1,
    });

    console.log(`[refreshPayload] KV 갱신 완료 courses=${courses.length}`);

    // Telegram 알림
    if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
      const sumText = summary
        ? `\n골프존 총 ${summary.totalGolfzonCourses}곳 / 매칭 ${summary.matched}곳 / 미매칭 ${summary.unmatched}곳`
        : "";
      await sendTelegram(
        env.TELEGRAM_BOT_TOKEN,
        env.TELEGRAM_CHAT_ID,
        `[라운드온] GitHub Action 코스 동기화 완료\n시각: ${now}\n코스: ${courses.length}곳${sumText}`
      );
    }
  } catch (e) {
    const errMsg = e instanceof Error ? e.message : String(e);
    console.error("[refreshPayload] KV 갱신 오류:", errMsg);

    if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
      await sendTelegram(
        env.TELEGRAM_BOT_TOKEN,
        env.TELEGRAM_CHAT_ID,
        `[라운드온] GitHub Action 코스 동기화 KV 갱신 실패\n시각: ${now}\n오류: ${errMsg}`
      );
    }
  }
}

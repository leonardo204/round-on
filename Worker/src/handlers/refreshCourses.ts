/**
 * POST /v1/courses/refresh
 *
 * 운영자 수동 트리거 — Cron과 동일한 로직을 즉시 실행
 *
 * 인증: HMAC-SHA256 서명
 *   X-Signature: hmac-sha256=<hex>
 *   body JSON: { timestamp: string, nonce: string }
 *   서명 대상: `${timestamp}:${nonce}`
 *
 * 중복 방지: nonce를 KV_COURSES에 5분간 저장
 */

import type { Env } from "../types.js";
import { runCoursesSync } from "./syncCourses.js";
import { errorResponse, jsonResponse } from "../middleware/security.js";

const NONCE_PREFIX = "refresh-nonce:";
const NONCE_TTL_SECONDS = 300; // 5분
const TIMESTAMP_SLACK_MS = 300_000; // 5분 이내 타임스탬프만 허용

interface RefreshBody {
  timestamp: string;
  nonce: string;
}

/** HMAC-SHA256 서명 검증 */
async function verifyHmac(
  secret: string,
  message: string,
  signature: string
): Promise<boolean> {
  // signature: "hmac-sha256=<hex>"
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

  return crypto.subtle.verify("HMAC", key, sigBytes.buffer as ArrayBuffer, enc.encode(message));
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

export async function handleRefreshCourses(
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
    return errorResponse(
      "UNAUTHORIZED",
      "X-Signature 헤더가 필요합니다.",
      401
    );
  }

  // 3. body 파싱
  let body: RefreshBody;
  try {
    body = (await request.json()) as RefreshBody;
  } catch {
    return errorResponse("VALIDATION_ERROR", "요청 body가 올바른 JSON이 아닙니다.", 400);
  }

  const { timestamp, nonce } = body;
  if (!timestamp || !nonce) {
    return errorResponse(
      "VALIDATION_ERROR",
      "timestamp와 nonce 필드가 필요합니다.",
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
    return errorResponse(
      "VALIDATION_ERROR",
      "이미 처리된 요청입니다 (nonce 중복).",
      409
    );
  }
  await env.KV_COURSES.put(nonceKey, "1", { expirationTtl: NONCE_TTL_SECONDS });

  // 7. 동기화 실행 (비동기 — 즉시 202 반환)
  ctx.waitUntil(runCoursesSync(env));

  return jsonResponse(
    { ok: true, message: "코스 데이터 갱신이 시작되었습니다." },
    202
  );
}

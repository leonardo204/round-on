/**
 * POST /api/share/stats — 통계 공유 viewer 생성
 * 통계 공유 v1 (2026-05-27)
 */

import type { Env, StatsSharePayload, StatsShareMeta } from "../types.js";
import { generateShortId } from "../lib/shortId.js";
import { hashPin } from "../lib/bcrypt.js";
import { checkRateLimit } from "../lib/rateLimit.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";

const MAX_PAYLOAD_BYTES = 1_048_576; // 1MB
const STATS_TTL = 7 * 86400;        // 7일 (초)

/** 통계 shortId: 's_' + base62 8자 (총 10자) */
async function generateStatsShortId(env: Env): Promise<string> {
  for (let i = 0; i < 3; i++) {
    const id = `s_${generateShortId()}`;
    const existing = await env.KV_STATS.get(`stats:${id}`);
    if (!existing) return id;
  }
  // collision 3회 실패 시 그냥 반환 (62^8 공간에서 사실상 불가)
  return `s_${generateShortId()}`;
}

/** 32자 random hex editToken 생성 */
function generateStatsEditToken(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

interface CreateStatsBody {
  payload: StatsSharePayload;
  pin?: string;
  deviceToken: string;
}

export async function handleCreateStatsShare(
  request: Request,
  env: Env
): Promise<Response> {
  // 1. Content-Length 사전 검사
  const contentLength = request.headers.get("Content-Length");
  if (contentLength && parseInt(contentLength, 10) > MAX_PAYLOAD_BYTES) {
    return errorResponse("PAYLOAD_TOO_LARGE", "요청 페이로드가 1MB 한도를 초과했습니다.", 413);
  }

  // 2. 바디 파싱
  let body: CreateStatsBody;
  try {
    const text = await request.text();
    if (text.length > MAX_PAYLOAD_BYTES) {
      return errorResponse("PAYLOAD_TOO_LARGE", "요청 페이로드가 1MB 한도를 초과했습니다.", 413);
    }
    body = JSON.parse(text) as CreateStatsBody;
  } catch {
    return errorResponse("VALIDATION_ERROR", "올바른 JSON 형식이 아닙니다.", 400);
  }

  // 3. 필수 필드 검증
  if (!body.deviceToken || typeof body.deviceToken !== "string") {
    return errorResponse("VALIDATION_ERROR", "deviceToken이 필요합니다.", 400);
  }
  if (!body.payload || typeof body.payload !== "object") {
    return errorResponse("VALIDATION_ERROR", "payload 데이터가 필요합니다.", 400);
  }
  if (!body.payload.cardKind || !["pr", "hcp", "trend"].includes(body.payload.cardKind)) {
    return errorResponse("VALIDATION_ERROR", "cardKind는 pr/hcp/trend 중 하나여야 합니다.", 400);
  }

  // 4. PIN 검증 (있을 때)
  if (body.pin !== undefined && body.pin !== null) {
    if (!/^[0-9]{4}$/.test(body.pin)) {
      return errorResponse("PIN_INVALID_FORMAT", "PIN은 4자리 숫자여야 합니다.", 400);
    }
  }

  // 5. Rate limit 검사 (deviceToken 당 1분 5건)
  const limited = await checkRateLimit(env, "share", body.deviceToken);
  if (limited) {
    return errorResponse(
      "RATE_LIMITED",
      "요청 한도를 초과했습니다. 잠시 후 다시 시도하세요.",
      429,
      { "Retry-After": "60" }
    );
  }

  // 6. shortId + editToken 생성 (collision check 포함)
  const shortId = await generateStatsShortId(env);
  const editToken = generateStatsEditToken();

  // 7. 메타 구성
  const now = Date.now();
  const expiresAt = now + STATS_TTL * 1000;

  let pinHash: string | undefined;
  if (body.pin) {
    pinHash = await hashPin(body.pin, env.BCRYPT_PEPPER);
  }

  const meta: StatsShareMeta = {
    shortId,
    payload: body.payload,
    editToken,
    ...(pinHash ? { pinHash } : {}),
    createdAt: now,
    expiresAt,
    deviceToken: body.deviceToken,
  };

  // 8. KV_STATS 저장 (7일 TTL)
  await env.KV_STATS.put(`stats:${shortId}`, JSON.stringify(meta), {
    expirationTtl: STATS_TTL,
  });

  // 9. 응답
  const responseBody = {
    shortId,
    url: `https://${env.VIEWER_DOMAIN}/s/${shortId}`,
    editToken,
    expiresAt: new Date(expiresAt).toISOString(),
  };

  console.log(`[stats:create] shortId=${shortId} cardKind=${body.payload.cardKind}`);

  return jsonResponse(responseBody, 201);
}

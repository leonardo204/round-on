/**
 * POST /api/share — viewer 생성
 * 30-API §3
 */

import type { Env, SharePayload, ShareMeta } from "../types.js";
import { generateShortId } from "../lib/shortId.js";
import { generateEditToken } from "../lib/editToken.js";
import { hashPin } from "../lib/bcrypt.js";
import { checkRateLimit } from "../lib/rateLimit.js";
import { maskPii } from "../lib/pii.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";

const MAX_PAYLOAD_BYTES = 1_048_576; // 1MB (30-API §8 권장)

export async function handleCreateShare(
  request: Request,
  env: Env
): Promise<Response> {
  // 1. Content-Length 사전 검사 (413 빠른 반환)
  const contentLength = request.headers.get("Content-Length");
  if (contentLength && parseInt(contentLength, 10) > MAX_PAYLOAD_BYTES) {
    return errorResponse(
      "PAYLOAD_TOO_LARGE",
      "요청 페이로드가 1MB 한도를 초과했습니다.",
      413
    );
  }

  // 2. 바디 파싱
  let body: SharePayload;
  try {
    const text = await request.text();
    if (text.length > MAX_PAYLOAD_BYTES) {
      return errorResponse(
        "PAYLOAD_TOO_LARGE",
        "요청 페이로드가 1MB 한도를 초과했습니다.",
        413
      );
    }
    body = JSON.parse(text) as SharePayload;
  } catch {
    return errorResponse("VALIDATION_ERROR", "올바른 JSON 형식이 아닙니다.", 400);
  }

  // 3. 필수 필드 검증
  if (!body.deviceToken || typeof body.deviceToken !== "string") {
    return errorResponse("VALIDATION_ERROR", "deviceToken이 필요합니다.", 400);
  }
  if (!body.round || typeof body.round !== "object") {
    return errorResponse("VALIDATION_ERROR", "round 데이터가 필요합니다.", 400);
  }
  if (!body.options || typeof body.options !== "object") {
    return errorResponse("VALIDATION_ERROR", "options가 필요합니다.", 400);
  }

  // 4. PIN 검증 (accessControl == "pin"일 때)
  if (body.options.accessControl === "pin") {
    const pin = body.options.pin;
    if (!pin || !/^[0-9]{4}$/.test(pin)) {
      return errorResponse(
        "PIN_INVALID_FORMAT",
        "PIN은 4자리 숫자여야 합니다.",
        400
      );
    }
  }

  // 5. Rate limit 검사 (deviceToken 당 1분 5건 — spec_3.md:280)
  const limited = await checkRateLimit(env, "share", body.deviceToken);
  if (limited) {
    return errorResponse(
      "RATE_LIMITED",
      "요청 한도를 초과했습니다. 잠시 후 다시 시도하세요.",
      429,
      { "Retry-After": "60" }
    );
  }

  // 6. Idempotency-Key 중복 검사 (30-API §9.7)
  if (body.idempotencyKey) {
    const idempKey = `idempotency:${body.idempotencyKey}`;
    const existing = await env.KV_META.get(idempKey);
    if (existing) {
      // 기존 응답 반환
      return jsonResponse(JSON.parse(existing), 201);
    }
  }

  // 7. PII 마스킹 — players[].name (33-SECURITY §7)
  if (body.round.players) {
    body.round.players = body.round.players.map((p) => ({
      ...p,
      name: maskPii(p.name),
    }));
  }
  // 캡션 PII 마스킹 (향후 사진 업로드 시에도 적용)

  // 8. shortId + editToken 생성
  const shortId = generateShortId();
  const editToken = generateEditToken();

  // 9. expiresAt 계산 (생성 시점 + 7일)
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  // 10. 메타 객체 구성 (PIN 제외)
  const meta: ShareMeta = {
    shortId,
    editToken,
    round: body.round,
    options: {
      nameVisibility: body.options.nameVisibility ?? "real",
      accessControl: body.options.accessControl ?? "public",
    },
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    photos: [],
  };

  // 11. KV 저장 — 7일 TTL (32-CLOUDFLARE §7)
  await env.KV_META.put(
    `share:${shortId}`,
    JSON.stringify(meta),
    { expirationTtl: 604800 }
  );

  // 12. PIN 해시 저장 (accessControl == "pin")
  if (body.options.accessControl === "pin" && body.options.pin) {
    const pinHash = await hashPin(body.options.pin, env.BCRYPT_PEPPER);
    await env.KV_META.put(
      `share:${shortId}:pinHash`,
      pinHash,
      { expirationTtl: 604800 }
    );
  }

  // 13. 응답 객체
  const responseBody = {
    shortId,
    url: `https://${env.VIEWER_DOMAIN}/${shortId}`,
    editToken,
    expiresAt: expiresAt.toISOString(),
  };

  // 14. Idempotency-Key 캐싱 (24시간 TTL)
  if (body.idempotencyKey) {
    await env.KV_META.put(
      `idempotency:${body.idempotencyKey}`,
      JSON.stringify(responseBody),
      { expirationTtl: 86400 }
    );
  }

  console.log(`[share:create] shortId=${shortId} editToken=tok_***`);

  return jsonResponse(responseBody, 201);
}

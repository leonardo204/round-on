/**
 * POST /api/share/stats — 통계 공유 viewer 생성
 * 통계 공유 v1 (2026-05-27)
 * v2 (2026-07-17) — optional ogImage(base64 PNG) 수용
 */

import type { Env, StatsSharePayload, StatsShareMeta } from "../types.js";
import { generateShortId } from "../lib/shortId.js";
import { hashPin } from "../lib/bcrypt.js";
import { checkRateLimit } from "../lib/rateLimit.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";
import {
  STATS_TTL,
  MAX_OG_BASE64_LENGTH,
  statsMetaKey,
  decodeOgImageBase64,
  putOgImage,
} from "../lib/statsOg.js";

const MAX_PAYLOAD_BYTES = 1_048_576; // 1MB — payload(JSON) 자체 상한

/**
 * 요청 body 전체 하드캡 = payload 1MB + ogImage base64 1.5MB + JSON 오버헤드 여유 64KB.
 *
 * body 전체에 1MB 를 걸면 ogImage 를 붙인 요청이 파싱 전에 413 으로 죽는다.
 * "og 때문에 공유가 실패하면 안 된다"는 계약을 지키려면 body 캡과 payload 캡을 분리해야 한다.
 * 상한 초과 og 는 파싱 후 개별 검증에서 걸러 og 만 생략한다(공유는 성공).
 */
const MAX_BODY_BYTES = MAX_PAYLOAD_BYTES + MAX_OG_BASE64_LENGTH + 65_536;

/** 통계 shortId: 's_' + base62 8자 (총 10자) */
async function generateStatsShortId(env: Env): Promise<string> {
  for (let i = 0; i < 3; i++) {
    const id = `s_${generateShortId()}`;
    const existing = await env.KV_STATS.get(statsMetaKey(id));
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
  /**
   * (v2, optional) iOS 가 렌더한 1080x1080 시그니처 카드 PNG — data URI prefix 없는 순수 base64.
   * 없으면 v1 과 동일 동작 (구버전 앱 하위 호환).
   */
  ogImage?: string;
}

/**
 * og:image 저장 시도 — 실패는 전부 흡수한다 (공유 생성은 언제나 성공해야 함)
 *
 * @param hasPin PIN 이 설정된 공유인지 — PIN 공유는 저장 자체를 skip 한다.
 *               PIN 은 링크만으로 내용을 못 보게 하는 장치인데, og:image 를 두면
 *               미리보기 카드로 스코어가 새어나간다. 쓰지 못할 이미지는 애초에 저장하지 않는다.
 * @returns 실제 저장 성공 여부 (meta.hasOgImage 플래그로 기록됨)
 */
async function storeOgImageIfPossible(
  env: Env,
  shortId: string,
  ogImage: string | undefined,
  hasPin: boolean
): Promise<boolean> {
  // v1 클라이언트 하위 호환 — ogImage 미전송 시 조용히 skip
  if (ogImage === undefined || ogImage === null) return false;

  if (typeof ogImage !== "string") {
    console.log(`[stats:og] 저장 거부 shortId=${shortId} reason=NOT_STRING`);
    return false;
  }

  if (hasPin) {
    console.log(
      `[stats:og] 저장 skip shortId=${shortId} reason=PIN_PROTECTED ` +
      `(PIN 공유는 미리보기로 스코어가 노출되므로 og 미저장)`
    );
    return false;
  }

  const decoded = decodeOgImageBase64(ogImage);
  if (!decoded.ok) {
    console.log(
      `[stats:og] 저장 거부 shortId=${shortId} reason=${decoded.reason} ` +
      `base64Len=${ogImage.length} limit=${MAX_OG_BASE64_LENGTH} — 공유는 og 없이 계속 생성`
    );
    return false;
  }

  try {
    await putOgImage(env, shortId, decoded.bytes, STATS_TTL);
    console.log(
      `[stats:og] 저장 완료 shortId=${shortId} bytes=${decoded.bytes.length} ttl=${STATS_TTL}s`
    );
    return true;
  } catch (err) {
    // KV 장애 등 — og 없이 공유는 계속 생성
    console.error(`[stats:og] KV 저장 실패 shortId=${shortId}:`, err);
    return false;
  }
}

export async function handleCreateStatsShare(
  request: Request,
  env: Env
): Promise<Response> {
  // 1. Content-Length 사전 검사 (body 전체 하드캡 — ogImage 포함 크기)
  const contentLength = request.headers.get("Content-Length");
  if (contentLength && parseInt(contentLength, 10) > MAX_BODY_BYTES) {
    return errorResponse("PAYLOAD_TOO_LARGE", "요청 페이로드가 한도를 초과했습니다.", 413);
  }

  // 2. 바디 파싱
  let body: CreateStatsBody;
  try {
    const text = await request.text();
    if (text.length > MAX_BODY_BYTES) {
      return errorResponse("PAYLOAD_TOO_LARGE", "요청 페이로드가 한도를 초과했습니다.", 413);
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
  // payload 자체 상한 — v1 의 1MB 계약 유지 (ogImage 는 별도 상한으로 검증)
  if (JSON.stringify(body.payload).length > MAX_PAYLOAD_BYTES) {
    return errorResponse("PAYLOAD_TOO_LARGE", "요청 페이로드가 1MB 한도를 초과했습니다.", 413);
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

  // 8. og:image 저장 (v2, optional)
  //    실패해도 공유 생성은 반드시 성공시킨다 — 미리보기 이미지 때문에 공유가 죽으면 안 된다.
  const hasOgImage = await storeOgImageIfPossible(env, shortId, body.ogImage, !!pinHash);

  const meta: StatsShareMeta = {
    shortId,
    payload: body.payload,
    editToken,
    ...(pinHash ? { pinHash } : {}),
    createdAt: now,
    expiresAt,
    deviceToken: body.deviceToken,
    ...(hasOgImage ? { hasOgImage: true } : {}),
  };

  // 9. KV_STATS 저장 (7일 TTL)
  await env.KV_STATS.put(statsMetaKey(shortId), JSON.stringify(meta), {
    expirationTtl: STATS_TTL,
  });

  // 10. 응답
  const responseBody = {
    shortId,
    url: `https://${env.VIEWER_DOMAIN}/s/${shortId}`,
    editToken,
    expiresAt: new Date(expiresAt).toISOString(),
  };

  console.log(
    `[stats:create] shortId=${shortId} cardKind=${body.payload.cardKind} ` +
    `pin=${pinHash ? "on" : "off"} og=${hasOgImage ? "stored" : "none"}`
  );

  return jsonResponse(responseBody, 201);
}

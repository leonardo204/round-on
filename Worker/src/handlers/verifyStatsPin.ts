/**
 * POST /s/:shortId/verify-pin — 통계 viewer PIN 검증 + 쿠키 발급
 * 통계 공유 v1 (2026-05-27)
 */

import type { Env, PinLockEntry, StatsShareMeta } from "../types.js";
import { verifyPin } from "../lib/bcrypt.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";
import { statsMetaKey } from "../lib/statsOg.js";

const MAX_ATTEMPTS = 5;
const LOCK_TTL = 3600;          // 1시간
const TIMING_DELAY_MS = 300;    // Timing Attack 방지

export async function handleVerifyStatsPin(
  request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  const startedAt = Date.now();

  // 1. 클라이언트 IP
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const lockKey = `pinlock:stats:${shortId}:${ip}`;

  // 2. 잠금 여부 확인
  const lockRaw = await env.KV_PINLOCK.get(lockKey);
  if (lockRaw) {
    const lock: PinLockEntry = JSON.parse(lockRaw) as PinLockEntry;
    if (lock.attempts >= MAX_ATTEMPTS) {
      return jsonResponse(
        { ok: false, locked: true, retryAfter: LOCK_TTL },
        429,
        { "Retry-After": String(LOCK_TTL) }
      );
    }
  }

  // 3. PIN 입력 파싱
  let body: { pin?: string };
  try {
    body = (await request.json()) as { pin?: string };
  } catch {
    return errorResponse("VALIDATION_ERROR", "올바른 JSON 형식이 아닙니다.", 400);
  }

  const pin = body.pin;

  // 4. 형식 검증
  if (!pin || !/^[0-9]{4}$/.test(pin)) {
    return errorResponse("PIN_INVALID_FORMAT", "PIN은 4자리 숫자여야 합니다.", 400);
  }

  // 5. KV 메타 조회
  const raw = await env.KV_STATS.get(statsMetaKey(shortId));
  if (!raw) {
    return errorResponse("NOT_FOUND", "통계 공유를 찾을 수 없습니다.", 404);
  }

  const meta: StatsShareMeta = JSON.parse(raw) as StatsShareMeta;

  // 6. PIN 해시 확인
  if (!meta.pinHash) {
    return errorResponse("NOT_FOUND", "이 통계 공유에는 PIN이 설정되어 있지 않습니다.", 404);
  }

  // 7. bcrypt 비교
  const isValid = await verifyPin(pin, meta.pinHash, env.BCRYPT_PEPPER);

  // 8. Timing Attack 방지 고정 지연
  const elapsed = Date.now() - startedAt;
  if (elapsed < TIMING_DELAY_MS) {
    await new Promise<void>((r) => setTimeout(r, TIMING_DELAY_MS - elapsed));
  }

  if (!isValid) {
    // 9. 오답 카운터 증가
    const currentLock: PinLockEntry = lockRaw
      ? (JSON.parse(lockRaw) as PinLockEntry)
      : { attempts: 0, firstAttemptAt: Date.now() };

    currentLock.attempts += 1;
    await env.KV_PINLOCK.put(lockKey, JSON.stringify(currentLock), {
      expirationTtl: LOCK_TTL,
    });

    const attempts = currentLock.attempts;

    if (attempts >= MAX_ATTEMPTS) {
      return jsonResponse(
        { ok: false, locked: true, retryAfter: LOCK_TTL },
        429,
        { "Retry-After": String(LOCK_TTL) }
      );
    }

    return jsonResponse({ ok: false, attempts, locked: false }, 401);
  }

  // 10. PIN 일치 → 쿠키 발급 (SameSite=Lax, HttpOnly, 24시간)
  const cookieName = `stats_pin_ok_${shortId}`;
  const setCookie = `${cookieName}=1; Max-Age=86400; HttpOnly; SameSite=Lax; Path=/`;

  // 오답 카운터 초기화
  if (lockRaw) {
    await env.KV_PINLOCK.delete(lockKey);
  }

  console.log(`[stats:pin:verified] shortId=${shortId} ip=${ip.substring(0, 6)}***`);

  return jsonResponse({ ok: true }, 200, { "Set-Cookie": setCookie });
}

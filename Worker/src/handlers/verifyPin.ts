/**
 * POST /:shortId/verify-pin — PIN 검증 + 세션 쿠키 발급
 * 33-SECURITY §5.3 정식 확정
 */

import type { Env, PinLockEntry } from "../types.js";
import { verifyPin } from "../lib/bcrypt.js";
import { createSessionCookie } from "../lib/session.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";

const MAX_ATTEMPTS = 5;   // 5회 오답 시 잠금 (spec_3.md:278)
const LOCK_TTL = 3600;    // 1시간 잠금 (spec_3.md:278)
const TIMING_DELAY_MS = 300; // Timing Attack 방지 고정 지연 (33-SECURITY §4.3)

export async function handleVerifyPin(
  request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  const startedAt = Date.now();

  // 1. 클라이언트 IP (33-SECURITY §5.2)
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const lockKey = `pinlock:${shortId}:${ip}`;

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
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
  }

  // 6. PIN 해시 조회
  const pinHash = await env.KV_META.get(`share:${shortId}:pinHash`);
  if (!pinHash) {
    // PIN이 설정되지 않은 viewer
    return errorResponse("NOT_FOUND", "이 라운드에는 PIN이 설정되어 있지 않습니다.", 404);
  }

  // 7. bcrypt 비교
  const isValid = await verifyPin(pin, pinHash, env.BCRYPT_PEPPER);

  // 8. Timing Attack 방지 — 300ms 고정 지연 (33-SECURITY §4.3)
  const elapsed = Date.now() - startedAt;
  if (elapsed < TIMING_DELAY_MS) {
    await new Promise<void>((r) =>
      setTimeout(r, TIMING_DELAY_MS - elapsed)
    );
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
      // 잠금 발동
      return jsonResponse(
        { ok: false, locked: true, retryAfter: LOCK_TTL },
        429,
        { "Retry-After": String(LOCK_TTL) }
      );
    }

    // PIN 불일치 (잠금 전)
    return jsonResponse(
      { ok: false, attempts, locked: false },
      401
    );
  }

  // 10. PIN 일치 → 세션 쿠키 발급 (33-SECURITY §5.4)
  const hmacKey = env.SESSION_HMAC_KEY;
  if (!hmacKey) {
    // SESSION_HMAC_KEY 미설정 시 쿠키 없이 200 반환 (로컬 개발 환경)
    console.warn("[verify-pin] SESSION_HMAC_KEY가 설정되지 않았습니다.");
    return jsonResponse({ ok: true });
  }

  const sessionCookie = await createSessionCookie(shortId, hmacKey);

  // 오답 카운터 초기화
  if (lockRaw) {
    await env.KV_PINLOCK.delete(lockKey);
  }

  console.log(`[pin:verified] shortId=${shortId} ip=${ip.substring(0, 6)}***`);

  return jsonResponse({ ok: true }, 200, {
    "Set-Cookie": sessionCookie,
  });
}

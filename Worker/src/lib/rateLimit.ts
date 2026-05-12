/**
 * Rate Limiting — Sliding Window Counter
 * 33-SECURITY §6: KV_RATELIMIT 사용, TTL 70초
 *
 * 규칙:
 *   POST /api/share        : deviceToken 당 1분 5건 (spec_3.md:280)
 *   POST /api/.../photos   : deviceToken 당 1분 30건 (30-API §9.5)
 */

import type { Env } from "../types.js";

export interface RateLimitRule {
  limit: number;
  windowMs: number; // 슬라이딩 윈도우 크기 (ms)
}

export const RATE_LIMITS = {
  share: { limit: 5, windowMs: 60_000 },    // 1분 5건
  photos: { limit: 30, windowMs: 60_000 },  // 1분 30건
} as const;

/**
 * 현재 분(floor to minute) 문자열 생성 — KV 키 suffix
 */
function currentMinuteKey(): string {
  const now = new Date();
  const y = now.getUTCFullYear();
  const M = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  const h = String(now.getUTCHours()).padStart(2, "0");
  const m = String(now.getUTCMinutes()).padStart(2, "0");
  return `${y}${M}${d}${h}${m}`;
}

/**
 * Rate limit 검사 + 카운터 증가
 * @returns true = 한도 초과 (429 반환 필요)
 */
export async function checkRateLimit(
  env: Env,
  type: "share" | "photos",
  deviceToken: string
): Promise<boolean> {
  const rule = RATE_LIMITS[type];
  const minute = currentMinuteKey();
  const key = `rl:${type}:${deviceToken}:${minute}`;

  const raw = await env.KV_RATELIMIT.get(key);
  const count = raw ? parseInt(raw, 10) : 0;

  if (count >= rule.limit) {
    return true; // 한도 초과
  }

  // 카운터 증가 + TTL 70초
  await env.KV_RATELIMIT.put(key, String(count + 1), {
    expirationTtl: 70,
  });

  return false;
}

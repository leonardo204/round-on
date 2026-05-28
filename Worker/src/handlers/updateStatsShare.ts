/**
 * PUT /api/share/stats/:shortId — 통계 공유 업데이트
 * 통계 공유 v1 (2026-05-27)
 */

import type { Env, StatsShareMeta, StatsSharePayload } from "../types.js";
import { hashPin } from "../lib/bcrypt.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";

interface UpdateStatsBody {
  payload?: Partial<StatsSharePayload>;
  pin?: string | null;  // null 전달 시 PIN 제거
}

export async function handleUpdateStatsShare(
  request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  // 1. editToken 검증 (Authorization: Bearer {editToken})
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return errorResponse("EDIT_TOKEN_INVALID", "Authorization 헤더가 필요합니다.", 401);
  }
  const editToken = authHeader.slice(7).trim();

  // 2. KV 조회
  const raw = await env.KV_STATS.get(`stats:${shortId}`);
  if (!raw) {
    return errorResponse("NOT_FOUND", "통계 공유를 찾을 수 없습니다.", 404);
  }

  const meta: StatsShareMeta = JSON.parse(raw) as StatsShareMeta;

  // 3. 만료 검사
  if (meta.expiresAt < Date.now()) {
    return errorResponse("EXPIRED", "이 통계 공유는 만료되었습니다.", 410);
  }

  // 4. editToken 일치 검사
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 5. 바디 파싱
  let body: UpdateStatsBody;
  try {
    body = (await request.json()) as UpdateStatsBody;
  } catch {
    return errorResponse("VALIDATION_ERROR", "올바른 JSON 형식이 아닙니다.", 400);
  }

  // 6. payload 부분 업데이트
  if (body.payload) {
    meta.payload = { ...meta.payload, ...body.payload };
  }

  // 7. PIN 변경 처리
  if (body.pin !== undefined) {
    if (body.pin === null || body.pin === "") {
      // PIN 제거
      delete meta.pinHash;
    } else {
      if (!/^[0-9]{4}$/.test(body.pin)) {
        return errorResponse("PIN_INVALID_FORMAT", "PIN은 4자리 숫자여야 합니다.", 400);
      }
      meta.pinHash = await hashPin(body.pin, env.BCRYPT_PEPPER);
    }
  }

  // 8. KV 갱신 (기존 expiresAt 유지)
  const remainingTtl = Math.max(
    1,
    Math.floor((meta.expiresAt - Date.now()) / 1000)
  );
  await env.KV_STATS.put(`stats:${shortId}`, JSON.stringify(meta), {
    expirationTtl: remainingTtl,
  });

  console.log(`[stats:update] shortId=${shortId}`);

  return jsonResponse({
    shortId,
    url: `https://${env.VIEWER_DOMAIN}/s/${shortId}`,
    expiresAt: new Date(meta.expiresAt).toISOString(),
  });
}

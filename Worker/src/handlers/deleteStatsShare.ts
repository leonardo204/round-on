/**
 * DELETE /api/share/stats/:shortId — 통계 공유 삭제
 * 통계 공유 v1 (2026-05-27)
 * v2 (2026-07-17) — og:image({shortId}:og) 동반 삭제
 */

import type { Env, StatsShareMeta } from "../types.js";
import { errorResponse } from "../middleware/security.js";
import { statsMetaKey, deleteOgImage } from "../lib/statsOg.js";

export async function handleDeleteStatsShare(
  request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  // 1. editToken 검증
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return errorResponse("EDIT_TOKEN_INVALID", "Authorization 헤더가 필요합니다.", 401);
  }
  const editToken = authHeader.slice(7).trim();

  // 2. KV 조회
  const raw = await env.KV_STATS.get(statsMetaKey(shortId));
  if (!raw) {
    return errorResponse("NOT_FOUND", "통계 공유를 찾을 수 없습니다.", 404);
  }

  const meta: StatsShareMeta = JSON.parse(raw) as StatsShareMeta;

  // 3. editToken 일치 검사
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 4. KV 삭제 — 페이로드 + og:image 동반 삭제 (수명주기 정합)
  //    og 를 남기면 공유 삭제 후에도 /og/{shortId}.png 가 TTL 만료 전까지 카드 이미지를 서빙한다.
  await env.KV_STATS.delete(statsMetaKey(shortId));
  await deleteOgImage(env, shortId);

  console.log(`[stats:delete] shortId=${shortId} og=deleted`);

  return new Response(null, { status: 204 });
}

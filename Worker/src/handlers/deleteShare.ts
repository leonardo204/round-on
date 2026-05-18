/**
 * DELETE /api/share/{shortId} — viewer 전체 삭제
 * 30-API §9.6, 33-SECURITY §9.2
 */

import type { Env, ShareMeta } from "../types.js";
import { errorResponse } from "../middleware/security.js";

export async function handleDeleteShare(
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

  // 2. KV 메타 조회
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
  }

  const meta: ShareMeta = JSON.parse(raw) as ShareMeta;

  // 3. editToken 일치 검사
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 4. KV 메타 삭제 (사진은 2026-05-18 폐기 — R2 정리 불필요)
  await env.KV_META.delete(`share:${shortId}`);
  await env.KV_META.delete(`share:${shortId}:pinHash`);

  console.log(`[share:delete] shortId=${shortId}`);

  // 6. 204 No Content
  return new Response(null, { status: 204 });
}

/**
 * DELETE /api/share/{shortId}/photos/{photoId} — 사진 삭제
 * 30-API §5.2
 */

import type { Env, ShareMeta } from "../types.js";
import { errorResponse } from "../middleware/security.js";

export async function handleDeletePhoto(
  request: Request,
  env: Env,
  shortId: string,
  photoId: string
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

  // 3. editToken 일치
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 4. photoId 존재 확인
  const photoIndex = (meta.photos ?? []).findIndex((p) => p.photoId === photoId);
  if (photoIndex === -1) {
    return errorResponse("NOT_FOUND", "사진을 찾을 수 없습니다.", 404);
  }

  // 5. R2 삭제
  await env.R2_PHOTOS.delete(`${shortId}/${photoId}.jpg`);

  // 6. KV 메타 갱신
  meta.photos = meta.photos.filter((p) => p.photoId !== photoId);

  const remainingTtl = Math.max(
    1,
    Math.floor((new Date(meta.expiresAt).getTime() - Date.now()) / 1000)
  );
  await env.KV_META.put(
    `share:${shortId}`,
    JSON.stringify(meta),
    { expirationTtl: remainingTtl }
  );

  console.log(`[photo:delete] shortId=${shortId} photoId=${photoId}`);

  return new Response(null, { status: 204 });
}

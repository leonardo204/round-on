/**
 * GET /:shortId/photo/:photoId — 사진 인라인/다운로드
 * 30-API §6.2, §6.3
 */

import type { Env, ShareMeta } from "../types.js";
import { errorResponse } from "../middleware/security.js";
import { applySecurityHeaders } from "../middleware/security.js";

export async function handleGetPhoto(
  request: Request,
  env: Env,
  shortId: string,
  photoId: string
): Promise<Response> {
  // 1. KV 메타 조회 (만료 및 사진 존재 확인)
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
  }

  const meta: ShareMeta = JSON.parse(raw) as ShareMeta;

  if (new Date(meta.expiresAt) < new Date()) {
    return errorResponse("EXPIRED", "이 라운드는 만료되었습니다.", 410);
  }

  // 2. photoId 존재 확인
  const photo = (meta.photos ?? []).find((p) => p.photoId === photoId);
  if (!photo) {
    return errorResponse("NOT_FOUND", "사진을 찾을 수 없습니다.", 404);
  }

  // 3. R2에서 파일 스트리밍
  const r2Object = await env.R2_PHOTOS.get(`${shortId}/${photoId}.jpg`);
  if (!r2Object) {
    return errorResponse("NOT_FOUND", "사진 파일이 없습니다.", 404);
  }

  // 4. download=1 파라미터 (§6.3)
  const url = new URL(request.url);
  const isDownload = url.searchParams.get("download") === "1";

  const headers = new Headers({
    "Content-Type": photo.contentType || "image/jpeg",
    "Cache-Control": "private, max-age=3600",
    "Content-Disposition": isDownload
      ? `attachment; filename="${photoId}.jpg"`
      : "inline",
  });

  const response = new Response(r2Object.body, { headers });
  return applySecurityHeaders(response, false);
}

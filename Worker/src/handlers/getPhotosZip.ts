/**
 * GET /:shortId/photos.zip — 전체 사진 ZIP 다운로드
 * 30-API §6.4
 */

import type { Env, ShareMeta } from "../types.js";
import { buildZip, type ZipFile } from "../lib/zip.js";
import { errorResponse } from "../middleware/security.js";
import { applySecurityHeaders } from "../middleware/security.js";

export async function handleGetPhotosZip(
  _request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  // 1. KV 메타 조회
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
  }

  const meta: ShareMeta = JSON.parse(raw) as ShareMeta;

  if (new Date(meta.expiresAt) < new Date()) {
    return errorResponse("EXPIRED", "이 라운드는 만료되었습니다.", 410);
  }

  const photos = meta.photos ?? [];
  if (photos.length === 0) {
    return errorResponse("NOT_FOUND", "이 라운드에 첨부된 사진이 없습니다.", 404);
  }

  // 2. R2에서 모든 사진 병렬 다운로드
  const r2Fetches = await Promise.all(
    photos.map(async (photo) => {
      const obj = await env.R2_PHOTOS.get(`${shortId}/${photo.photoId}.jpg`);
      if (!obj) return null;
      const data = new Uint8Array(await obj.arrayBuffer());
      return { photo, data };
    })
  );

  // 3. ZipFile 목록 구성
  const zipFiles: ZipFile[] = r2Fetches
    .filter((item): item is NonNullable<typeof item> => item !== null)
    .map(({ data }, i) => ({
      filename: `roundon-${shortId}-${String(i + 1).padStart(2, "0")}.jpg`,
      data,
    }));

  // 4. ZIP 생성
  const zipBuffer = await buildZip(zipFiles);

  const headers = new Headers({
    "Content-Type": "application/zip",
    "Content-Disposition": `attachment; filename="roundon-${shortId}.zip"`,
    "Content-Length": String(zipBuffer.length),
    "Cache-Control": "private, no-store",
  });

  // Uint8Array → ArrayBuffer (Workers BodyInit 호환)
  const response = new Response(zipBuffer.buffer as ArrayBuffer, { headers });
  return applySecurityHeaders(response, false);
}

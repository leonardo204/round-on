/**
 * POST /api/share/{shortId}/photos — 사진 업로드
 * 30-API §5.1, multipart/form-data
 */

import type { Env, ShareMeta, Photo } from "../types.js";
import { checkRateLimit } from "../lib/rateLimit.js";
import { maskPii } from "../lib/pii.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";

const MAX_PHOTO_BYTES = 10 * 1024 * 1024; // 10MB (spec_3.md:279)
const MAX_PHOTOS_PER_VIEWER = 30;          // 30장 (spec_3.md:279)

function generatePhotoId(): string {
  // ph_ + 12자 base62 무작위
  const chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  return "ph_" + Array.from(bytes, (b) => chars[b % 62]).join("");
}

export async function handleUploadPhoto(
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

  // 2. deviceToken (Rate limit용)
  const deviceToken = request.headers.get("X-Device-Token") ?? "unknown";

  // 3. Rate limit (1분 30건 — 30-API §9.5)
  const limited = await checkRateLimit(env, "photos", deviceToken);
  if (limited) {
    return errorResponse(
      "RATE_LIMITED",
      "사진 업로드 한도를 초과했습니다. 잠시 후 다시 시도하세요.",
      429,
      { "Retry-After": "60" }
    );
  }

  // 4. KV 메타 조회
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
  }

  const meta: ShareMeta = JSON.parse(raw) as ShareMeta;

  // 5. 만료 검사
  if (new Date(meta.expiresAt) < new Date()) {
    return errorResponse("EXPIRED", "이 라운드는 만료되었습니다.", 410);
  }

  // 6. editToken 일치
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 7. 사진 최대 장수 검사
  if ((meta.photos ?? []).length >= MAX_PHOTOS_PER_VIEWER) {
    return errorResponse(
      "PAYLOAD_TOO_LARGE",
      `viewer당 최대 ${MAX_PHOTOS_PER_VIEWER}장까지 업로드할 수 있습니다.`,
      413
    );
  }

  // 8. multipart/form-data 파싱
  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return errorResponse("VALIDATION_ERROR", "multipart/form-data 파싱 실패.", 400);
  }

  const file = formData.get("photo");
  if (!file || typeof file === "string") {
    return errorResponse("VALIDATION_ERROR", "photo 파일 필드가 없습니다.", 400);
  }

  // 9. 파일 크기 검사
  if (file.size > MAX_PHOTO_BYTES) {
    return errorResponse(
      "PAYLOAD_TOO_LARGE",
      "사진 1장 최대 10MB 한도를 초과했습니다.",
      413
    );
  }

  // 10. MIME 타입 검증
  const contentType = file.type || "image/jpeg";
  if (!["image/jpeg", "image/png", "image/heic", "image/heif"].includes(contentType)) {
    return errorResponse("VALIDATION_ERROR", "JPEG, PNG, HEIC 형식만 지원합니다.", 400);
  }

  // 11. 캡션 PII 마스킹
  const rawCaption = formData.get("caption");
  const caption =
    rawCaption && typeof rawCaption === "string"
      ? maskPii(rawCaption)
      : undefined;

  const rawHoleNumber = formData.get("holeNumber");
  const holeNumber =
    rawHoleNumber && typeof rawHoleNumber === "string"
      ? parseInt(rawHoleNumber, 10)
      : undefined;

  // 12. R2 업로드
  const photoId = generatePhotoId();
  const r2Key = `${shortId}/${photoId}.jpg`;
  const fileBuffer = await file.arrayBuffer();

  await env.R2_PHOTOS.put(r2Key, fileBuffer, {
    httpMetadata: { contentType },
  });

  // 13. KV 메타 갱신 (사진 목록에 추가)
  const photo: Photo = {
    photoId,
    holeNumber,
    caption,
    contentType,
    size: file.size,
    uploadedAt: new Date().toISOString(),
  };

  meta.photos = [...(meta.photos ?? []), photo];

  const remainingTtl = Math.max(
    1,
    Math.floor((new Date(meta.expiresAt).getTime() - Date.now()) / 1000)
  );
  await env.KV_META.put(
    `share:${shortId}`,
    JSON.stringify(meta),
    { expirationTtl: remainingTtl }
  );

  console.log(`[photo:upload] shortId=${shortId} photoId=${photoId} size=${file.size}`);

  return jsonResponse(
    {
      photoId,
      remoteURL: `https://${env.VIEWER_DOMAIN}/${shortId}/photo/${photoId}`,
    },
    201
  );
}

/**
 * 라우팅 매처 — 자체 구현 (itty-router 없이)
 * 7개 엔드포인트 + /healthz + robots.txt
 *
 * 엔드포인트 목록 (30-API §3~§6):
 *  POST   /api/share
 *  PUT    /api/share/:shortId
 *  DELETE /api/share/:shortId
 *  POST   /api/share/:shortId/photos
 *  DELETE /api/share/:shortId/photos/:photoId
 *  GET    /:shortId
 *  GET    /:shortId/photo/:photoId
 *  GET    /:shortId/photos.zip
 *  POST   /:shortId/verify-pin        (33-SECURITY §5.3)
 *  GET    /healthz
 *  GET    /robots.txt
 */

import type { Env } from "./types.js";
import { handleCreateShare }  from "./handlers/createShare.js";
import { handleUpdateShare }  from "./handlers/updateShare.js";
import { handleDeleteShare }  from "./handlers/deleteShare.js";
import { handleUploadPhoto }  from "./handlers/uploadPhoto.js";
import { handleDeletePhoto }  from "./handlers/deletePhoto.js";
import { handleGetPhoto }     from "./handlers/getPhoto.js";
import { handleGetPhotosZip } from "./handlers/getPhotosZip.js";
import { handleGetViewer }    from "./handlers/getViewer.js";
import { handleVerifyPin }    from "./handlers/verifyPin.js";
import { errorResponse }      from "./middleware/security.js";

// shortId 패턴: base62 8자 (33-SECURITY §2)
const SHORT_ID_RE = /^[0-9A-Za-z]{8}$/;

function isValidShortId(id: string): boolean {
  return SHORT_ID_RE.test(id);
}

/**
 * 메인 라우트 디스패처
 */
export async function route(
  request: Request,
  env: Env,
  _ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const { pathname } = url;
  const method = request.method.toUpperCase();

  // ── /healthz ────────────────────────────────────────────────────────────
  if (pathname === "/healthz" && method === "GET") {
    return new Response(JSON.stringify({ ok: true, service: "roundon-viewer" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── /robots.txt ─────────────────────────────────────────────────────────
  if (pathname === "/robots.txt" && method === "GET") {
    return new Response("User-agent: *\nDisallow: /\n", {
      headers: { "Content-Type": "text/plain" },
    });
  }

  // ── /api/share ──────────────────────────────────────────────────────────
  if (pathname === "/api/share") {
    if (method === "POST") {
      return handleCreateShare(request, env);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /api/share/:shortId ──────────────────────────────────────────────────
  const apiShareMatch = pathname.match(/^\/api\/share\/([^/]+)$/);
  if (apiShareMatch) {
    const shortId = apiShareMatch[1];
    if (!isValidShortId(shortId)) {
      return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
    }
    if (method === "PUT") {
      return handleUpdateShare(request, env, shortId);
    }
    if (method === "DELETE") {
      return handleDeleteShare(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /api/share/:shortId/photos ─────────────────────────────────────────
  const apiPhotosMatch = pathname.match(/^\/api\/share\/([^/]+)\/photos$/);
  if (apiPhotosMatch) {
    const shortId = apiPhotosMatch[1];
    if (!isValidShortId(shortId)) {
      return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
    }
    if (method === "POST") {
      return handleUploadPhoto(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /api/share/:shortId/photos/:photoId ───────────────────────────────
  const apiPhotoDeleteMatch = pathname.match(
    /^\/api\/share\/([^/]+)\/photos\/([^/]+)$/
  );
  if (apiPhotoDeleteMatch) {
    const shortId = apiPhotoDeleteMatch[1];
    const photoId = apiPhotoDeleteMatch[2];
    if (!isValidShortId(shortId)) {
      return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
    }
    if (method === "DELETE") {
      return handleDeletePhoto(request, env, shortId, photoId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /:shortId ──────────────────────────────────────────────────────────
  const viewerMatch = pathname.match(/^\/([^/]+)$/);
  if (viewerMatch) {
    const shortId = viewerMatch[1];
    if (!isValidShortId(shortId)) {
      // 알 수 없는 경로 → 404
      return errorResponse("NOT_FOUND", "페이지를 찾을 수 없습니다.", 404);
    }
    if (method === "GET") {
      return handleGetViewer(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /:shortId/photo/:photoId ─────────────────────────────────────────
  const photoMatch = pathname.match(/^\/([^/]+)\/photo\/([^/]+)$/);
  if (photoMatch) {
    const shortId = photoMatch[1];
    const photoId = photoMatch[2];
    if (!isValidShortId(shortId)) {
      return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
    }
    if (method === "GET") {
      return handleGetPhoto(request, env, shortId, photoId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /:shortId/photos.zip ─────────────────────────────────────────────
  const zipMatch = pathname.match(/^\/([^/]+)\/photos\.zip$/);
  if (zipMatch) {
    const shortId = zipMatch[1];
    if (!isValidShortId(shortId)) {
      return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
    }
    if (method === "GET") {
      return handleGetPhotosZip(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /:shortId/verify-pin ──────────────────────────────────────────────
  const verifyPinMatch = pathname.match(/^\/([^/]+)\/verify-pin$/);
  if (verifyPinMatch) {
    const shortId = verifyPinMatch[1];
    if (!isValidShortId(shortId)) {
      return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
    }
    if (method === "POST") {
      return handleVerifyPin(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── 기본 404 ─────────────────────────────────────────────────────────
  return errorResponse("NOT_FOUND", "페이지를 찾을 수 없습니다.", 404);
}

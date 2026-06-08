/**
 * 라우팅 매처 — 자체 구현 (itty-router 없이)
 *
 * 엔드포인트 목록 (30-API §3~§6):
 *  POST   /api/share
 *  PUT    /api/share/:shortId
 *  DELETE /api/share/:shortId
 *  GET    /:shortId
 *  POST   /:shortId/verify-pin        (33-SECURITY §5.3)
 *  GET    /healthz
 *  GET    /robots.txt
 *
 * 사진 관련 엔드포인트(/photos, /photo/:id, /photos.zip)는 2026-05-18 제거
 * — 개인정보보호 및 서버 비용 절감 목적.
 */

import type { Env } from "./types.js";
import { handleCreateShare } from "./handlers/createShare.js";
import { handleUpdateShare } from "./handlers/updateShare.js";
import { handleDeleteShare } from "./handlers/deleteShare.js";
import { handleGetViewer }   from "./handlers/getViewer.js";
import { handleVerifyPin }   from "./handlers/verifyPin.js";
import { handleGetCourses }  from "./handlers/getCourses.js";
import { handleRefreshCourses } from "./handlers/refreshCourses.js";
import { handleRefreshPayload } from "./handlers/refreshPayload.js";
import { handleGetLanding }     from "./handlers/getLanding.js";
import { handleGetPrivacy }     from "./handlers/getPrivacy.js";
import { handleGetAppAdsTxt }  from "./handlers/getAppAdsTxt.js";
import { handleCreateStatsShare } from "./handlers/createStatsShare.js";
import { handleGetStatsViewer }   from "./handlers/getStatsViewer.js";
import { handleUpdateStatsShare } from "./handlers/updateStatsShare.js";
import { handleDeleteStatsShare } from "./handlers/deleteStatsShare.js";
import { handleVerifyStatsPin }   from "./handlers/verifyStatsPin.js";
import { errorResponse }     from "./middleware/security.js";

// shortId 패턴: base62 8자 (33-SECURITY §2)
const SHORT_ID_RE = /^[0-9A-Za-z]{8}$/;

// 통계 shortId 패턴: 's_' + base62 8자 (총 10자)
const STATS_SHORT_ID_RE = /^s_[0-9A-Za-z]{8}$/;

function isValidStatsShortId(id: string): boolean {
  return STATS_SHORT_ID_RE.test(id);
}

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

  // ── / — 앱 소개 페이지 ──────────────────────────────────────────────────
  if (pathname === "/" && method === "GET") {
    return handleGetLanding();
  }

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

  // ── /favicon.ico ─── 빈 응답으로 404 방지 (브라우저 자동 요청)
  if (pathname === "/favicon.ico" && method === "GET") {
    return new Response(null, {
      status: 204,
      headers: { "Cache-Control": "public, max-age=86400" },
    });
  }

  // ── /v1/* — 코스 DB API (SHORT_ID_RE 보다 반드시 먼저 처리) ────────────

  // GET /v1/courses
  if (pathname === "/v1/courses" && method === "GET") {
    return handleGetCourses(request, env, "courses");
  }

  // GET /v1/course-pars
  if (pathname === "/v1/course-pars" && method === "GET") {
    return handleGetCourses(request, env, "course-pars");
  }

  // POST /v1/courses/refresh (운영자 수동 트리거 — Worker 내부에서 골프존 fetch 실행)
  if (pathname === "/v1/courses/refresh" && method === "POST") {
    return handleRefreshCourses(request, env, _ctx);
  }

  // POST /v1/courses/refresh-payload (GitHub Action이 수집 완료 payload를 직접 전달)
  if (pathname === "/v1/courses/refresh-payload" && method === "POST") {
    return handleRefreshPayload(request, env, _ctx);
  }

  // /v1/* fallthrough → 404 (알 수 없는 v1 경로)
  if (pathname.startsWith("/v1/")) {
    return errorResponse("NOT_FOUND", "API 엔드포인트를 찾을 수 없습니다.", 404);
  }

  // ── /api/share/stats — 통계 공유 (라운드 share 보다 먼저 처리) ─────────
  if (pathname === "/api/share/stats") {
    if (method === "POST") {
      return handleCreateStatsShare(request, env);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /api/share/stats/:shortId ────────────────────────────────────────────
  const apiStatsMatch = pathname.match(/^\/api\/share\/stats\/(s_[^/]+)$/);
  if (apiStatsMatch) {
    const shortId = apiStatsMatch[1];
    if (!isValidStatsShortId(shortId)) {
      return errorResponse("NOT_FOUND", "통계 공유를 찾을 수 없습니다.", 404);
    }
    if (method === "PUT") {
      return handleUpdateStatsShare(request, env, shortId);
    }
    if (method === "DELETE") {
      return handleDeleteStatsShare(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /s/:shortId — 통계 viewer (라운드 /:shortId catch-all 보다 먼저) ──────
  const statsViewerMatch = pathname.match(/^\/s\/(s_[^/]+)$/);
  if (statsViewerMatch) {
    const shortId = statsViewerMatch[1];
    if (method === "GET") {
      return handleGetStatsViewer(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
  }

  // ── /s/:shortId/verify-pin — 통계 PIN 검증 ──────────────────────────────
  const statsVerifyPinMatch = pathname.match(/^\/s\/(s_[^/]+)\/verify-pin$/);
  if (statsVerifyPinMatch) {
    const shortId = statsVerifyPinMatch[1];
    if (!isValidStatsShortId(shortId)) {
      return errorResponse("NOT_FOUND", "통계 공유를 찾을 수 없습니다.", 404);
    }
    if (method === "POST") {
      return handleVerifyStatsPin(request, env, shortId);
    }
    return errorResponse("VALIDATION_ERROR", "지원하지 않는 메서드입니다.", 405);
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

  // ── /app-ads.txt — AdMob 퍼블리셔 검증 (catch-all /:shortId 보다 반드시 앞) ─
  // GET + HEAD 모두 처리 (일부 검증 크롤러가 HEAD 선요청 — Workers가 HEAD body 자동 제거)
  if (pathname === "/app-ads.txt" && (method === "GET" || method === "HEAD")) {
    return handleGetAppAdsTxt();
  }

  // ── /privacy — 개인정보 처리방침 (catch-all /:shortId 보다 반드시 앞) ─
  if (pathname === "/privacy" && method === "GET") {
    return handleGetPrivacy();
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

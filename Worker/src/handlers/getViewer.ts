/**
 * GET /:shortId — viewer HTML (정상/PIN/410/404 4분기)
 * 30-API §6.1, 31-VIEWER_HTML §2
 */

import type { Env, ShareMeta } from "../types.js";
import { renderViewer } from "../views/viewer.js";
import { renderPinLock } from "../views/pinLock.js";
import { render410, render404 } from "../views/error.js";
import { getSessionShortId } from "../lib/session.js";
import { applySecurityHeaders } from "../middleware/security.js";

function htmlResponse(html: string, status: number): Response {
  const r = new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=UTF-8",
      "Cache-Control": "private, no-store",
    },
  });
  return applySecurityHeaders(r, true); // viewer HTML → CSP 적용
}

export async function handleGetViewer(
  request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  // 1. KV 메타 조회
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    // shortId 없음
    return htmlResponse(render404(), 404);
  }

  const meta: ShareMeta = JSON.parse(raw) as ShareMeta;

  // 2. 만료 검사 (7일 — 30-API §6.1)
  if (new Date(meta.expiresAt) < new Date()) {
    return htmlResponse(render410(), 410);
  }

  // 3. accessControl 분기
  if (meta.options.accessControl === "pin") {
    // 3a. 세션 쿠키 검증 (33-SECURITY §5.5)
    const hmacKey = env.SESSION_HMAC_KEY;
    if (hmacKey) {
      const sessionShortId = await getSessionShortId(request, hmacKey);
      if (sessionShortId === shortId) {
        // 유효한 세션 → 스코어카드 HTML 응답
        return htmlResponse(
          renderViewer({ shortId, meta, domain: env.VIEWER_DOMAIN }),
          200
        );
      }
    }
    // 세션 없음/만료 → PIN 잠금 화면
    return htmlResponse(renderPinLock(shortId, meta), 200);
  }

  // 4. 공개 viewer
  return htmlResponse(
    renderViewer({ shortId, meta, domain: env.VIEWER_DOMAIN }),
    200
  );
}

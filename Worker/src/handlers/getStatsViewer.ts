/**
 * GET /s/:shortId — 통계 viewer HTML
 * 통계 공유 v1 (2026-05-27)
 */

import type { Env, StatsShareMeta } from "../types.js";
import { renderStatsViewer } from "../views/statsViewer.js";
import { renderStatsPinLock } from "../views/statsViewer.js";
import { applySecurityHeaders } from "../middleware/security.js";
import { statsMetaKey } from "../lib/statsOg.js";

/** shortId 패턴: 's_' + base62 8자 */
const STATS_SHORT_ID_RE = /^s_[0-9A-Za-z]{8}$/;

function htmlResponse(html: string, status: number): Response {
  const r = new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "private, max-age=0, must-revalidate",
    },
  });
  return applySecurityHeaders(r, true);
}

function render410Html(): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>만료된 통계</title>
<style>body{font-family:-apple-system,sans-serif;background:#f4f7f4;color:#1a2620;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;}.box{text-align:center;padding:40px 24px;}.num{font-size:64px;font-weight:800;color:#1c6b43;line-height:1;}.msg{margin-top:12px;font-size:16px;color:#5d6b63;}.brand{margin-top:24px;font-size:13px;color:#94a39b;}</style>
</head><body><div class="box"><div class="num">410</div><div class="msg">통계 공유가 만료되었습니다.<br/>라운드온에서 다시 공유해 보세요.</div><div class="brand">라운드온 · Round-On</div></div></body></html>`;
}

function render404Html(): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>페이지를 찾을 수 없습니다</title>
<style>body{font-family:-apple-system,sans-serif;background:#f4f7f4;color:#1a2620;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;}.box{text-align:center;padding:40px 24px;}.num{font-size:64px;font-weight:800;color:#1c6b43;line-height:1;}.msg{margin-top:12px;font-size:16px;color:#5d6b63;}.brand{margin-top:24px;font-size:13px;color:#94a39b;}</style>
</head><body><div class="box"><div class="num">404</div><div class="msg">페이지를 찾을 수 없습니다.</div><div class="brand">라운드온 · Round-On</div></div></body></html>`;
}

export async function handleGetStatsViewer(
  request: Request,
  env: Env,
  rawShortId: string
): Promise<Response> {
  // 1. shortId 정규식 검증
  if (!STATS_SHORT_ID_RE.test(rawShortId)) {
    return htmlResponse(render404Html(), 404);
  }

  // 2. KV 조회
  const raw = await env.KV_STATS.get(statsMetaKey(rawShortId));
  if (!raw) {
    return htmlResponse(render404Html(), 404);
  }

  const meta: StatsShareMeta = JSON.parse(raw) as StatsShareMeta;

  // 3. 만료 검사
  if (meta.expiresAt < Date.now()) {
    return htmlResponse(render410Html(), 410);
  }

  // 4. PIN 분기
  if (meta.pinHash) {
    // 쿠키 stats_pin_ok_{shortId} 확인
    const cookieHeader = request.headers.get("Cookie") ?? "";
    const cookieName = `stats_pin_ok_${rawShortId}`;
    const hasPinCookie = cookieHeader
      .split(";")
      .some((part) => part.trim().startsWith(`${cookieName}=`));

    if (!hasPinCookie) {
      return htmlResponse(renderStatsPinLock(rawShortId, meta), 200);
    }
  }

  // 5. 정상 viewer
  return htmlResponse(
    renderStatsViewer({ shortId: rawShortId, meta, domain: env.VIEWER_DOMAIN }),
    200
  );
}

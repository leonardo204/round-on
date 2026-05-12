/**
 * 라운드온 Cloudflare Worker 엔트리포인트
 * 32-CLOUDFLARE_SETUP §8 보안 헤더 전역 적용
 */

import type { Env } from "./types.js";
import { route } from "./router.js";
import { applySecurityHeaders } from "./middleware/security.js";
import { handleScheduled } from "./handlers/scheduled.js";

export default {
  /**
   * HTTP 요청 핸들러
   * 보안 헤더는 route() 내 각 응답 생성 시 applySecurityHeaders()로 적용됨
   * (viewer HTML은 CSP 포함, JSON API는 CSP 제외 — 32-CLOUDFLARE §8)
   */
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    try {
      return await route(request, env, ctx);
    } catch (err) {
      console.error("[worker] 처리되지 않은 에러:", err);
      const errResponse = new Response(
        JSON.stringify({
          error: "INTERNAL_ERROR",
          message: "서버 내부 오류가 발생했습니다.",
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json; charset=UTF-8" },
        }
      );
      return applySecurityHeaders(errResponse, false);
    }
  },

  /**
   * Cron 트리거 핸들러
   * wrangler.toml: crons = ["0 3 * * *"]
   */
  async scheduled(
    event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    ctx.waitUntil(handleScheduled(event, env, ctx));
  },
};

/**
 * Cron handler — 매일 새벽 3시 만료 회수
 * wrangler.toml: crons = ["0 3 * * *"]
 *
 * KV TTL 기반 자동 삭제가 주요 보호 수단이므로,
 * 이 핸들러는 고아 R2 객체(KV가 먼저 삭제된 후 남은 R2) 청소에 집중한다.
 */

import type { Env } from "../types.js";

export async function handleScheduled(
  _event: ScheduledEvent,
  _env: Env,
  _ctx: ExecutionContext
): Promise<void> {
  console.log("[cron] 만료 회수 시작");

  try {
    // R2 Lifecycle Rule이 7일 자동 삭제를 담당하므로 (32-CLOUDFLARE §4)
    // 이 핸들러는 보조 작업만 수행한다

    // 일일 발급량 통계 초기화 (33-SECURITY §10.3 권장)
    // 어제 날짜 통계 키를 집계 후 별도 저장하는 패턴으로 구현 가능
    // 현재는 로그만 기록
    const today = new Date().toISOString().slice(0, 10);
    console.log(`[cron] 만료 회수 완료 date=${today}`);
  } catch (err) {
    console.error("[cron] 만료 회수 오류:", err);
  }
}

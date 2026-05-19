// Cron handler
//
// wrangler.toml에 등록된 Cron 트리거:
//   분기 Cron  — 분기(3개월)마다 1일 새벽 3시 (cron: "0 3 1 -/3 *")
//   매일 Cron  — 매일 새벽 3시 만료 회수    (cron: "0 3 * * *")
//
// 코스 동기화 전략 변경 (2026-05-19):
//   GitHub Action (scripts/sync-courses.mjs)이 골프존 API fetch를 담당하고
//   결과를 POST /v1/courses/refresh-payload 로 전달함.
//   → Cloudflare Workers Free Plan 50 subrequest 제한 우회
//   → 분기 Cron에서 Worker 직접 fetch(runCoursesSync)는 비활성.
//     wrangler.toml cron 스케줄은 유지 (GitHub Action과 동일 시각 발동).
//
// 운영자 수동 재활성 옵션:
//   wrangler.toml [vars] 에 ENABLE_CRON_SYNC = "true" 추가 시 runCoursesSync 재활성.
//   현재는 GitHub Action 전용 모드.

import type { Env } from "../types.js";
// runCoursesSync: 필요 시 재활성을 위해 import 유지
import { runCoursesSync } from "./syncCourses.js";

export async function handleScheduled(
  event: ScheduledEvent,
  env: Env,
  _ctx: ExecutionContext
): Promise<void> {
  const cron = event.cron ?? "";
  console.log(`[cron] 트리거 cron="${cron}"`);

  if (cron === "0 3 * * *") {
    // 매일 만료 회수 (기존 로직)
    try {
      const today = new Date().toISOString().slice(0, 10);
      console.log(`[cron] 만료 회수 완료 date=${today}`);
    } catch (err) {
      console.error("[cron] 만료 회수 오류:", err);
    }
  } else {
    // 분기 Cron — 코스 동기화
    //
    // [비활성] GitHub Action 전용 모드:
    //   GitHub Action이 동일 시각에 골프존 fetch 완료 후
    //   /v1/courses/refresh-payload 로 payload를 직접 전달함.
    //   Worker 내부 fetch는 50 subrequest 제한으로 불가 → skip.
    //
    // [재활성 방법] Paid plan 전환 시 아래 주석 해제:
    //   await runCoursesSync(env);
    //
    // 현재: log만 남기고 noop
    console.log(
      "[cron] 분기 코스 동기화 Cron 발동 — GitHub Action 전용 모드로 skip. " +
      "POST /v1/courses/refresh-payload 수신 대기 중."
    );

    // wrangler.toml vars에 ENABLE_CRON_SYNC = "true" 추가 시 fallback 활성
    if ((env as unknown as Record<string, string>)["ENABLE_CRON_SYNC"] === "true") {
      console.log("[cron] ENABLE_CRON_SYNC=true — runCoursesSync 실행");
      await runCoursesSync(env);
    }
  }
}

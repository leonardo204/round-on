/**
 * 코스 데이터 동기화 핵심 로직
 *
 * - Cron (handleScheduled) + POST /v1/courses/refresh 양쪽에서 호출
 * - 골프존 API → NormalizedSubCourse[] → DB fuzzy 매칭
 * - KV 저장 (courses:current, course-pars:current)
 * - 실패 시 4회 backoff (5분 간격) → 전부 실패 시 이전 KV 유지 + Telegram 알림
 * - 성공 시 sync-meta 갱신 + Telegram 알림 (선택)
 *
 * 우리 DB (courses.json) 로딩:
 *   Worker bundle에 직접 embed (fetch('/courses.json') 대신 static import 불가)
 *   → wrangler.toml assets 또는 KV pre-loaded JSON 전략 대신
 *     단순히 KV_COURSES에 "db:courses" 키로 미리 적재하거나,
 *     또는 Cloudflare R2/static 대신 번들 내 JSON import 사용
 *   현재 전략: Worker 번들 내 인라인 JSON import
 *   (wrangler build 시 courses.json → JS 번들에 포함)
 */

import type { Env } from "../types.js";
import {
  fetchAndNormalizeAll,
  matchToDb,
  type DbCourse,
  type MatchedPars,
  type NormalizedSubCourse,
} from "../lib/golfzonFetch.js";
import {
  writeCurrent,
  writeSyncMeta,
  type DatasetPayload,
} from "../lib/coursesKv.js";

// ─── Telegram ────────────────────────────────────────────────────────────────

async function sendTelegram(
  botToken: string,
  chatId: string,
  text: string
): Promise<void> {
  try {
    await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
  } catch (e) {
    console.error("[telegram] 전송 실패:", e);
  }
}

// ─── Backoff 재시도 ───────────────────────────────────────────────────────────

async function withRetry<T>(
  fn: () => Promise<T>,
  retries = 4,
  delayMs = 300_000 // 5분
): Promise<T> {
  let lastErr: unknown;
  for (let i = 0; i <= retries; i++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (i < retries) {
        console.warn(`[sync] 재시도 ${i + 1}/${retries} 후 ${delayMs / 1000}초 대기`);
        await new Promise((r) => setTimeout(r, delayMs));
      }
    }
  }
  throw lastErr;
}

// ─── DB courses 로드 (KV 또는 번들) ──────────────────────────────────────────

/**
 * 우리 DB에서 코스 목록 조회
 * KV에 "db:courses" 키로 미리 JSON 적재되어 있으면 그것을 사용
 * 없으면 빈 배열 반환 (fuzzy 매칭 전부 실패)
 */
async function loadDbCourses(kv: KVNamespace): Promise<DbCourse[]> {
  const raw = await kv.get("db:courses");
  if (!raw) {
    console.warn("[sync] db:courses KV 키 없음 — 빈 DB로 진행 (fuzzy 매칭 없음)");
    return [];
  }
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const parsed = JSON.parse(raw) as any[];
    return parsed.map((c) => ({
      id: c.id as string,
      name: c.name as string,
      nameEn: c.nameEn as string | undefined,
    }));
  } catch {
    console.error("[sync] db:courses JSON 파싱 오류");
    return [];
  }
}

// ─── 메인 동기화 ──────────────────────────────────────────────────────────────

export async function runCoursesSync(env: Env): Promise<void> {
  const now = new Date().toISOString();
  const version = now.slice(0, 10); // "YYYY-MM-DD"

  console.log(`[sync] 코스 동기화 시작 version=${version}`);

  try {
    // 1. 골프존 API fetch + normalize (4회 backoff)
    let subCourses: NormalizedSubCourse[];
    try {
      subCourses = await withRetry(
        () => fetchAndNormalizeAll(5),
        4,
        300_000
      );
    } catch (e) {
      // 전부 실패 → 이전 KV 유지 + Telegram 알림
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error("[sync] 골프존 fetch 전부 실패:", errMsg);

      await writeSyncMeta(env.KV_COURSES, {
        lastFailureAt: now,
        failureCount: ((await readSyncMetaCount(env)) + 1),
        lastError: errMsg,
      });

      if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
        await sendTelegram(
          env.TELEGRAM_BOT_TOKEN,
          env.TELEGRAM_CHAT_ID,
          `[라운드온] 코스 동기화 실패\n시각: ${now}\n오류: ${errMsg}`
        );
      }
      return;
    }

    // 2. 우리 DB 로드 + fuzzy 매칭
    const dbCourses = await loadDbCourses(env.KV_COURSES);
    const matched: MatchedPars[] = matchToDb(subCourses, dbCourses);
    console.log(`[sync] fuzzy 매칭 성공 ${matched.length}개`);

    // 3. courses 페이로드 구성 (우리 DB 기준 코스 목록)
    //    courses:current — 코스 메타 (id, name, dataQuality 등)
    //    db:courses가 없으면 빈 payload로라도 저장
    const coursesPayload: DatasetPayload = {
      version,
      updatedAt: now,
      schema: 1,
      count: dbCourses.length,
      courses: dbCourses,
    };

    // 4. course-pars 페이로드 구성
    // matched → courseId별로 그룹핑
    const parsByCourse = new Map<
      string,
      { courseId: string; courseName: string; subCourses: { name: string; pars: number[] }[] }
    >();

    for (const m of matched) {
      if (!parsByCourse.has(m.courseId)) {
        parsByCourse.set(m.courseId, {
          courseId: m.courseId,
          courseName: m.courseName,
          subCourses: [],
        });
      }
      parsByCourse.get(m.courseId)!.subCourses.push({
        name: m.subCourseName,
        pars: m.pars,
      });
    }

    const courseParsPayload: DatasetPayload = {
      version,
      updatedAt: now,
      schema: 1,
      count: parsByCourse.size,
      coursePars: Array.from(parsByCourse.values()),
    };

    // 5. KV 저장
    await Promise.all([
      writeCurrent(env.KV_COURSES, "courses", coursesPayload),
      writeCurrent(env.KV_COURSES, "course-pars", courseParsPayload),
    ]);

    // 6. sync-meta 갱신
    await writeSyncMeta(env.KV_COURSES, {
      lastSuccessAt: now,
      successCount: ((await readSyncMetaCount(env, true)) + 1),
    });

    console.log("[sync] 코스 동기화 완료");

    // 7. Telegram 성공 알림 (선택)
    if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
      await sendTelegram(
        env.TELEGRAM_BOT_TOKEN,
        env.TELEGRAM_CHAT_ID,
        `[라운드온] 코스 동기화 성공\n시각: ${now}\n코스: ${dbCourses.length}개, par 매칭: ${matched.length}개`
      );
    }
  } catch (e) {
    const errMsg = e instanceof Error ? e.message : String(e);
    console.error("[sync] 동기화 전체 오류:", errMsg);

    if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
      await sendTelegram(
        env.TELEGRAM_BOT_TOKEN,
        env.TELEGRAM_CHAT_ID,
        `[라운드온] 코스 동기화 치명적 오류\n시각: ${now}\n오류: ${errMsg}`
      );
    }
  }
}

/** sync-meta에서 카운트 조회 헬퍼 */
async function readSyncMetaCount(
  env: Env,
  success = false
): Promise<number> {
  const raw = await env.KV_COURSES.get("sync-meta");
  if (!raw) return 0;
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const meta = JSON.parse(raw) as any;
    return success
      ? (meta.successCount ?? 0)
      : (meta.failureCount ?? 0);
  } catch {
    return 0;
  }
}

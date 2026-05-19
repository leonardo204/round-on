/**
 * GET /v1/courses
 * GET /v1/course-pars
 *
 * - Bearer API key 인증 (COURSES_API_KEY)
 * - ETag + If-None-Match → 304
 * - Cache-Control: private, max-age=604800, stale-while-revalidate=86400
 */

import type { Env } from "../types.js";
import type { DatasetKey } from "../lib/coursesKv.js";
import { readCurrent } from "../lib/coursesKv.js";
import { errorResponse } from "../middleware/security.js";

/** Bearer 토큰 검증 */
function verifyBearer(request: Request, apiKey: string | undefined): boolean {
  if (!apiKey) return false; // 키 미설정 → 거부
  const auth = request.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return false;
  const token = auth.slice("Bearer ".length).trim();
  return token === apiKey;
}

export async function handleGetCourses(
  request: Request,
  env: Env,
  dataset: DatasetKey
): Promise<Response> {
  // 1. 인증
  if (!verifyBearer(request, env.COURSES_API_KEY)) {
    return errorResponse(
      "UNAUTHORIZED",
      "유효한 API 키가 필요합니다.",
      401,
      { "WWW-Authenticate": "Bearer" }
    );
  }

  // 2. KV에서 데이터 + ETag 조회
  const { data, etag } = await readCurrent(env.KV_COURSES, dataset);

  if (!data || !etag) {
    // 아직 Cron이 한 번도 실행되지 않은 상태
    return errorResponse(
      "NOT_FOUND",
      "코스 데이터가 아직 준비되지 않았습니다. 나중에 다시 시도해 주세요.",
      503
    );
  }

  // 3. 304 처리
  const ifNoneMatch = request.headers.get("If-None-Match");
  if (ifNoneMatch && ifNoneMatch === etag) {
    return new Response(null, {
      status: 304,
      headers: {
        ETag: etag,
        "Cache-Control": "private, max-age=604800, stale-while-revalidate=86400",
      },
    });
  }

  // 4. 200 응답
  const body = JSON.stringify(data);
  return new Response(body, {
    status: 200,
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
      "ETag": etag,
      "Cache-Control": "private, max-age=604800, stale-while-revalidate=86400",
    },
  });
}

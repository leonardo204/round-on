/**
 * GET /og/:shortId.png — 통계 공유 og:image PNG 서빙
 * 통계 공유 v2 (2026-07-17)
 *
 * iOS 앱이 공유 생성 시 업로드한 1080x1080 시그니처 카드 PNG 를 KV_STATS 에서 읽어 서빙한다.
 * 카톡/슬랙 등 링크 미리보기 크롤러가 statsViewer 의 og:image 메타를 통해 이 경로를 요청한다.
 *
 * 헤더 규약은 handlers/getWatchShot.ts 와 동일 (Content-Type: image/png + immutable 캐시).
 * 단 소스가 다르다 — getWatchShot 은 번들 base64, 이쪽은 KV 바이트다 (번들 크기 제약, lib/statsOg.ts 참조).
 *
 * 보안 (33-SECURITY §7.7 연장):
 *  PIN 이 걸린 통계 공유는 링크만으로 내용을 못 보게 하는 것이 목적이다.
 *  og:image 를 노출하면 미리보기 카드 이미지로 스코어가 그대로 새어나가므로 PIN 공유는 항상 404 를 반환한다.
 *  (생성 시점에도 저장 자체를 skip 하지만, v1 메타/업데이트 경로를 대비해 서빙 시점에서도 재검사한다 — 이중 방어)
 */

import type { Env, StatsShareMeta } from "../types.js";
import { statsMetaKey, getOgImage } from "../lib/statsOg.js";

/** shortId 패턴: 's_' + base62 8자 */
const STATS_SHORT_ID_RE = /^s_[0-9A-Za-z]{8}$/;

/** 크롤러 대상 경로이므로 본문 없는 단순 404 (HTML 404 페이지 불필요) */
function notFound(): Response {
  return new Response("Not found", {
    status: 404,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

export async function handleGetStatsOgImage(
  env: Env,
  rawShortId: string
): Promise<Response> {
  // 1. shortId 형식 검증 — 통계 공유는 's_' + base62 8자
  if (!STATS_SHORT_ID_RE.test(rawShortId)) {
    return notFound();
  }

  // 2. 메타 조회 (PIN/만료 판정에 필요)
  const raw = await env.KV_STATS.get(statsMetaKey(rawShortId));
  if (!raw) {
    return notFound();
  }

  let meta: StatsShareMeta;
  try {
    meta = JSON.parse(raw) as StatsShareMeta;
  } catch {
    console.error(`[stats:og] meta 파싱 실패 shortId=${rawShortId}`);
    return notFound();
  }

  // 3. 만료 검사 — 만료된 공유의 미리보기 이미지도 노출하지 않는다
  if (meta.expiresAt < Date.now()) {
    console.log(`[stats:og] 만료된 공유 요청 shortId=${rawShortId}`);
    return notFound();
  }

  // 4. PIN 보호 검사 — PIN 공유는 og:image 자체를 노출하지 않는다 (스코어 유출 차단)
  if (meta.pinHash) {
    console.log(`[stats:og] PIN 보호 공유 — og 노출 차단 shortId=${rawShortId}`);
    return notFound();
  }

  // 5. PNG 바이트 조회
  const bytes = await getOgImage(env, rawShortId);
  if (!bytes) {
    return notFound();
  }

  // 6. 서빙 — getWatchShot.ts 헤더 규약 준수.
  //    shortId 당 이미지는 교체되지 않으므로(updateStatsShare 는 og 교체 미지원) immutable 안전.
  //    max-age 는 공유 TTL(7일)과 동일하게 맞춘다.
  console.log(`[stats:og] 서빙 shortId=${rawShortId} bytes=${bytes.byteLength}`);
  return new Response(bytes, {
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=604800, immutable",
    },
  });
}

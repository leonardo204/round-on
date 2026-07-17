/**
 * PUT /api/share/stats/:shortId — 통계 공유 업데이트
 * 통계 공유 v1 (2026-05-27)
 * v2 (2026-07-17) — og:image 정책 반영
 *
 * og:image 교체는 지원하지 않는다 (요청 body 의 ogImage 필드 미수용). 근거:
 *  1) /og/{shortId}.png 는 immutable 캐시(max-age 7일)로 서빙된다 — 같은 URL 의 내용이 바뀌면
 *     브라우저/엣지가 최대 7일간 옛 이미지를 계속 서빙해 카드와 viewer 내용이 어긋난다.
 *  2) og PNG 는 "공유 생성 시점의 시그니처 카드 렌더 결과" 다. 카드 내용을 바꾸려면 새 공유를 만드는 것이 맞다.
 *  3) update 의 실제 용도는 닉네임/PIN 정정 수준이라 카드 재업로드 수요가 없다.
 * → payload 갱신 시 기존 og 는 그대로 유지한다.
 *
 * 예외: PIN 이 새로 설정되면 og 를 즉시 삭제한다 (아래 7 단계 — 보안 우선).
 */

import type { Env, StatsShareMeta, StatsSharePayload } from "../types.js";
import { hashPin } from "../lib/bcrypt.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";
import { statsMetaKey, deleteOgImage } from "../lib/statsOg.js";

interface UpdateStatsBody {
  payload?: Partial<StatsSharePayload>;
  pin?: string | null;  // null 전달 시 PIN 제거
}

export async function handleUpdateStatsShare(
  request: Request,
  env: Env,
  shortId: string
): Promise<Response> {
  // 1. editToken 검증 (Authorization: Bearer {editToken})
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return errorResponse("EDIT_TOKEN_INVALID", "Authorization 헤더가 필요합니다.", 401);
  }
  const editToken = authHeader.slice(7).trim();

  // 2. KV 조회
  const raw = await env.KV_STATS.get(statsMetaKey(shortId));
  if (!raw) {
    return errorResponse("NOT_FOUND", "통계 공유를 찾을 수 없습니다.", 404);
  }

  const meta: StatsShareMeta = JSON.parse(raw) as StatsShareMeta;

  // 3. 만료 검사
  if (meta.expiresAt < Date.now()) {
    return errorResponse("EXPIRED", "이 통계 공유는 만료되었습니다.", 410);
  }

  // 4. editToken 일치 검사
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 5. 바디 파싱
  let body: UpdateStatsBody;
  try {
    body = (await request.json()) as UpdateStatsBody;
  } catch {
    return errorResponse("VALIDATION_ERROR", "올바른 JSON 형식이 아닙니다.", 400);
  }

  // 6. payload 부분 업데이트
  if (body.payload) {
    meta.payload = { ...meta.payload, ...body.payload };
  }

  // 7. PIN 변경 처리
  //    PIN 이 새로 설정되면 og:image 를 삭제한다 — PIN 은 링크만으로 내용을 못 보게 하는 장치인데
  //    미리보기 카드가 남아 있으면 스코어가 그대로 새어나간다 (서빙 시점 pinHash 검사와 이중 방어).
  //    PIN 제거 시 og 복구는 불가하다 (원본 PNG 를 보관하지 않음) — 미리보기 없이 동작하며,
  //    이는 ogImage 를 보내지 않은 v1 공유와 동일한 상태다.
  let ogRevoked = false;
  if (body.pin !== undefined) {
    if (body.pin === null || body.pin === "") {
      // PIN 제거
      delete meta.pinHash;
    } else {
      if (!/^[0-9]{4}$/.test(body.pin)) {
        return errorResponse("PIN_INVALID_FORMAT", "PIN은 4자리 숫자여야 합니다.", 400);
      }
      meta.pinHash = await hashPin(body.pin, env.BCRYPT_PEPPER);
      if (meta.hasOgImage) {
        await deleteOgImage(env, shortId);
        meta.hasOgImage = false;
        ogRevoked = true;
      }
    }
  }

  // 8. KV 갱신 (기존 expiresAt 유지)
  const remainingTtl = Math.max(
    1,
    Math.floor((meta.expiresAt - Date.now()) / 1000)
  );
  await env.KV_STATS.put(statsMetaKey(shortId), JSON.stringify(meta), {
    expirationTtl: remainingTtl,
  });

  console.log(
    `[stats:update] shortId=${shortId} pin=${meta.pinHash ? "on" : "off"} ` +
    `og=${ogRevoked ? "revoked(PIN 설정)" : meta.hasOgImage ? "kept" : "none"}`
  );

  return jsonResponse({
    shortId,
    url: `https://${env.VIEWER_DOMAIN}/s/${shortId}`,
    expiresAt: new Date(meta.expiresAt).toISOString(),
  });
}

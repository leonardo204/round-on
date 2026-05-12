/**
 * PUT /api/share/{shortId} — viewer 업데이트
 * 30-API §4
 */

import type { Env, ShareMeta, ShareOptions } from "../types.js";
import { hashPin } from "../lib/bcrypt.js";
import { maskPii } from "../lib/pii.js";
import { jsonResponse, errorResponse } from "../middleware/security.js";

interface UpdateShareBody {
  round?: ShareMeta["round"];
  options?: Partial<ShareOptions>;
}

export async function handleUpdateShare(
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

  // 2. KV 메타 조회
  const raw = await env.KV_META.get(`share:${shortId}`);
  if (!raw) {
    // shortId 없음 또는 만료 (만료 시 KV TTL로 자동 삭제)
    return errorResponse("NOT_FOUND", "라운드를 찾을 수 없습니다.", 404);
  }

  const meta: ShareMeta = JSON.parse(raw) as ShareMeta;

  // 3. 만료 검사
  if (new Date(meta.expiresAt) < new Date()) {
    return errorResponse("EXPIRED", "이 라운드는 만료되었습니다.", 410);
  }

  // 4. editToken 일치 검사
  if (meta.editToken !== editToken) {
    return errorResponse("EDIT_TOKEN_INVALID", "editToken이 일치하지 않습니다.", 401);
  }

  // 5. 바디 파싱
  let body: UpdateShareBody;
  try {
    body = (await request.json()) as UpdateShareBody;
  } catch {
    return errorResponse("VALIDATION_ERROR", "올바른 JSON 형식이 아닙니다.", 400);
  }

  // 6. partial update
  if (body.round) {
    // PII 마스킹
    if (body.round.players) {
      body.round.players = body.round.players.map((p) => ({
        ...p,
        name: maskPii(p.name),
      }));
    }
    meta.round = { ...meta.round, ...body.round };
  }

  if (body.options) {
    if (body.options.accessControl === "pin") {
      const pin = body.options.pin;
      if (!pin || !/^[0-9]{4}$/.test(pin)) {
        return errorResponse("PIN_INVALID_FORMAT", "PIN은 4자리 숫자여야 합니다.", 400);
      }
      // PIN 해시 갱신
      const pinHash = await hashPin(pin, env.BCRYPT_PEPPER);
      await env.KV_META.put(
        `share:${shortId}:pinHash`,
        pinHash,
        { expirationTtl: 604800 }
      );
    } else if (body.options.accessControl === "public") {
      // 공개로 전환 시 기존 PIN 해시 삭제
      await env.KV_META.delete(`share:${shortId}:pinHash`);
    }

    meta.options = {
      ...meta.options,
      nameVisibility: body.options.nameVisibility ?? meta.options.nameVisibility,
      accessControl: body.options.accessControl ?? meta.options.accessControl,
    };
  }

  // 7. KV 갱신 (남은 TTL 유지: expiresAt 기준 재계산)
  const remainingTtl = Math.max(
    1,
    Math.floor((new Date(meta.expiresAt).getTime() - Date.now()) / 1000)
  );
  await env.KV_META.put(
    `share:${shortId}`,
    JSON.stringify(meta),
    { expirationTtl: remainingTtl }
  );

  console.log(`[share:update] shortId=${shortId} editToken=tok_***`);

  return jsonResponse({
    shortId,
    url: `https://${env.VIEWER_DOMAIN}/${shortId}`,
    expiresAt: meta.expiresAt,
  });
}

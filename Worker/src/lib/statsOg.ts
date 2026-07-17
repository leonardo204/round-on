/**
 * 통계 공유 KV 키 규약 + og:image 저장 유틸
 * 통계 공유 v2 (2026-07-17) — og:image 추가
 *
 * 배경:
 *  v1 은 정적 PNG 자산 미배포를 이유로 og:image 를 생략했고 카톡은 og:title+og:description 으로만 폴백했다.
 *  v2 는 iOS 앱이 이미 렌더하는 1080x1080 시그니처 카드 PNG 를 공유 생성 시 함께 업로드받아 KV 에 저장하고,
 *  GET /og/:shortId.png 로 서빙한다.
 *
 * 왜 KV 인가 (번들 크기 제약 — 반드시 유지할 것):
 *  Worker 번들이 gzip 2.56MB 로 무료 플랜 한도 3MB 에 여유가 440KB 뿐이다.
 *  base64 자산 번들 임베드(assets/watchShots.ts 방식)나 satori/resvg wasm 추가는 한도를 넘긴다.
 *  → PNG 는 번들이 아니라 KV 에만 둔다.
 *
 * KV 네임스페이스 주의:
 *  KV_STATS 는 KV_META 와 동일 namespace id 의 alias 다 (wrangler.toml).
 *  통계 shortId 는 's_' prefix 가 보장되므로 라운드 share 키(share:{base62 8자})와 충돌하지 않는다.
 */

import type { Env } from "../types.js";

/**
 * 통계 공유 페이로드 TTL — 7일 (초)
 * og:image 도 이 상수를 재사용한다 (페이로드와 수명 동일 — 하드코딩 중복 금지).
 */
export const STATS_TTL = 7 * 86400;

/** 페이로드 메타 키 — stats:{shortId} */
export function statsMetaKey(shortId: string): string {
  return `stats:${shortId}`;
}

/**
 * og:image 키 — stats:{shortId}:og
 * 페이로드 키(stats:{shortId})와 prefix 를 맞춘다 — 같은 공유의 두 레코드가 같은 네임스페이스에서
 * 나란히 보여야 운영 시 추적이 쉽다.
 */
export function statsOgKey(shortId: string): string {
  return `${statsMetaKey(shortId)}:og`;
}

/** og:image base64 문자열 길이 상한 — 1.5MB */
export const MAX_OG_BASE64_LENGTH = 1_572_864;

/** iOS 시그니처 카드 렌더 크기 (고정) — og:image:width/height 메타에 사용 */
export const OG_IMAGE_WIDTH = 1080;
export const OG_IMAGE_HEIGHT = 1080;

/** PNG 매직바이트 — \x89PNG\r\n\x1a\n */
const PNG_MAGIC = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/** og:image 검증 실패 사유 (로깅용) */
export type OgRejectReason = "TOO_LARGE" | "DECODE_FAILED" | "NOT_PNG" | "EMPTY";

export type OgDecodeResult =
  | { ok: true; bytes: Uint8Array }
  | { ok: false; reason: OgRejectReason };

/**
 * base64 PNG 디코드 + 검증
 *
 * 검증 순서: 길이 상한 → base64 디코드 → PNG 매직바이트.
 * 실패해도 예외를 던지지 않는다 — 호출부가 "공유는 성공, og 만 생략" 으로 처리해야 하기 때문.
 *
 * @param b64 data URI prefix 없는 순수 base64 문자열
 */
export function decodeOgImageBase64(b64: string): OgDecodeResult {
  if (!b64 || b64.length === 0) {
    return { ok: false, reason: "EMPTY" };
  }
  // 1. 크기 상한 (base64 문자열 길이 기준 — 디코드 전에 먼저 걸러 CPU 낭비 방지)
  if (b64.length > MAX_OG_BASE64_LENGTH) {
    return { ok: false, reason: "TOO_LARGE" };
  }

  // 2. base64 디코드 (형식 오류 시 atob 가 throw)
  let bytes: Uint8Array;
  try {
    const bin = atob(b64);
    bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  } catch {
    return { ok: false, reason: "DECODE_FAILED" };
  }

  // 3. PNG 매직바이트 검증 (다른 포맷/임의 바이트 저장 방지)
  if (bytes.length < PNG_MAGIC.length) {
    return { ok: false, reason: "NOT_PNG" };
  }
  for (let i = 0; i < PNG_MAGIC.length; i++) {
    if (bytes[i] !== PNG_MAGIC[i]) {
      return { ok: false, reason: "NOT_PNG" };
    }
  }

  return { ok: true, bytes };
}

/**
 * og:image 를 KV_STATS 에 저장 (페이로드와 동일 TTL)
 *
 * KV 장애 시 throw 한다 — 호출부가 catch 해서 "og 없이 공유는 계속 생성" 으로 처리해야 한다.
 */
export async function putOgImage(
  env: Env,
  shortId: string,
  bytes: Uint8Array,
  ttlSeconds: number = STATS_TTL
): Promise<void> {
  // KV 는 ArrayBufferView 저장을 지원 — base64 재인코딩 없이 원본 바이트 그대로 둔다
  await env.KV_STATS.put(statsOgKey(shortId), bytes, {
    expirationTtl: Math.max(60, Math.floor(ttlSeconds)),
  });
}

/** og:image 조회 — 없으면 null */
export async function getOgImage(
  env: Env,
  shortId: string
): Promise<ArrayBuffer | null> {
  return env.KV_STATS.get(statsOgKey(shortId), "arrayBuffer");
}

/** og:image 삭제 (공유 삭제 / PIN 신규 설정 시) */
export async function deleteOgImage(env: Env, shortId: string): Promise<void> {
  await env.KV_STATS.delete(statsOgKey(shortId));
}

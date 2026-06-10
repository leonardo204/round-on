import { WATCH_SHOTS } from "../assets/watchShots.js";

/**
 * GET /watch/:name.png — Apple Watch 스크린샷 PNG 서빙
 *
 * 랜딩 페이지의 워치 섹션에서 <img>로 참조. base64 인라인 대신 라우트로 서빙하여
 * HTML 페이로드를 가볍게 유지(에셋 캐싱 + 병렬 로드).
 */
export function handleGetWatchShot(name: string): Response {
  const b64 = WATCH_SHOTS[name];
  if (!b64) {
    return new Response("Not found", { status: 404 });
  }
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return new Response(bytes, {
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=604800, immutable",
    },
  });
}

import { PHONE_SHOTS } from "../assets/phoneShots.js";

/**
 * GET /phone/:name.png — iPhone 스크린샷 PNG/JPEG 서빙
 *
 * 랜딩 페이지의 iPhone 섹션에서 <img>로 참조. base64 인라인 대신 라우트로 서빙하여
 * HTML 페이로드를 가볍게 유지. (gps는 개인정보 주소 블러 처리본)
 */
export function handleGetPhoneShot(name: string): Response {
  const b64 = PHONE_SHOTS[name];
  if (!b64) {
    return new Response("Not found", { status: 404 });
  }
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  // counter/home/share는 JPEG, gps는 PNG — 디코더가 매직바이트로 판별하므로
  // 브라우저 호환 위해 공통 image/* 처리: PNG 매직(0x89 0x50)이면 png, 아니면 jpeg.
  const isPng = bytes[0] === 0x89 && bytes[1] === 0x50;
  return new Response(bytes, {
    headers: {
      "Content-Type": isPng ? "image/png" : "image/jpeg",
      "Cache-Control": "public, max-age=604800, immutable",
    },
  });
}

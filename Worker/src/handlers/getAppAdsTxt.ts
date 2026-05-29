/**
 * GET /app-ads.txt — AdMob 퍼블리셔 검증 파일
 *
 * App Store / Google AdMob 검증을 위해 golf.zerolive.co.kr/app-ads.txt 에서 제공.
 * 퍼블리셔 ID: pub-4410880415888380
 * ref: https://support.google.com/admob/answer/9973961
 */
export function handleGetAppAdsTxt(): Response {
  const body = "google.com, pub-4410880415888380, DIRECT, f08c47fec0942fa0\n";
  return new Response(body, {
    headers: {
      "Content-Type": "text/plain; charset=UTF-8",
      "Cache-Control": "public, max-age=86400",
    },
  });
}

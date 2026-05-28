/**
 * 보안 헤더 미들웨어
 * 32-CLOUDFLARE_SETUP §8, 33-SECURITY §8.2~§8.3
 *
 * 모든 Worker 응답에 전역 적용
 * viewer HTML에는 CSP 추가
 */

/**
 * 보안 헤더 5종 + (viewer HTML의 경우) CSP 적용
 * @param response 원본 응답
 * @param isViewer viewer HTML 여부 (CSP 적용 여부 결정)
 */
export function applySecurityHeaders(
  response: Response,
  isViewer = false
): Response {
  const h = new Headers(response.headers);

  // 1. HSTS (32-CLOUDFLARE §8, 33-SECURITY §8.2)
  h.set(
    "Strict-Transport-Security",
    "max-age=31536000; includeSubDomains; preload"
  );

  // 2. MIME 스니핑 방지
  h.set("X-Content-Type-Options", "nosniff");

  // 3. 리퍼러 누출 방지
  h.set("Referrer-Policy", "no-referrer");

  // 4. 불필요한 브라우저 권한 차단
  h.set("Permissions-Policy", "geolocation=(), camera=(), microphone=()");

  // 5. 클릭재킹 방지
  h.set("X-Frame-Options", "DENY");

  // viewer HTML 전용 CSP
  // 31-VIEWER_HTML.md: CSP 적용은 viewer HTML만, JSON API 제외
  if (isViewer) {
    h.set(
      "Content-Security-Policy",
      [
        "default-src 'self'",
        // 인라인 스타일 + 스크립트 허용 (viewer는 템플릿 리터럴 inline)
        // unpkg.com: Leaflet CDN (statsViewer Leaflet 인터랙티브 지도)
        "style-src 'self' 'unsafe-inline' https://unpkg.com",
        // Cloudflare가 자동 주입하는 beacon.min.js 허용 (static.cloudflareinsights.com)
        // unpkg.com: Leaflet CDN JS
        "script-src 'self' 'unsafe-inline' https://static.cloudflareinsights.com https://unpkg.com",
        // Cloudflare insights는 cloudflareinsights.com으로 비콘 전송
        "connect-src 'self' https://cloudflareinsights.com",
        // data: (인라인 이미지), OSM tile 서버 (Leaflet 지도 타일)
        "img-src 'self' data: https://*.tile.openstreetmap.org",
        "font-src 'self'",
        "form-action 'self'",
        "frame-ancestors 'none'",
      ].join("; ")
    );
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: h,
  });
}

/**
 * JSON API 응답 생성 헬퍼 (보안 헤더 포함)
 */
export function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders?: HeadersInit
): Response {
  const r = new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
      "Cache-Control": "no-store",
      ...(extraHeaders ?? {}),
    },
  });
  return applySecurityHeaders(r, false);
}

/**
 * 에러 JSON 응답 헬퍼
 */
export function errorResponse(
  error: string,
  message: string,
  status: number,
  extraHeaders?: HeadersInit
): Response {
  return jsonResponse({ error, message }, status, extraHeaders);
}

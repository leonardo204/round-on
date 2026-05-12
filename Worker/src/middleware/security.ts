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
        "style-src 'self' 'unsafe-inline'",
        "script-src 'self' 'unsafe-inline'",
        // 이미지: Worker 경유 사진 URL만 허용 (R2 직접 URL 차단)
        "img-src 'self'",
        // 폼 action: 같은 origin만
        "form-action 'self'",
        // 외부 자원 로드 금지
        "connect-src 'self'",
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

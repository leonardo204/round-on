/**
 * 에러 HTML 뷰 — 410/404/429
 * 31-VIEWER_HTML §2: 단순 카드 (중앙 정렬), 헤더만
 */

import { escapeHtml } from "../lib/escape.js";

interface ErrorViewOptions {
  title: string;
  message: string;
  statusCode: number;
}

function baseHtml(opts: ErrorViewOptions): string {
  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="theme-color" content="#7FB069" />
  <title>${escapeHtml(opts.title)} — 라운드온</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif;
      padding: env(safe-area-inset-top) env(safe-area-inset-right)
               env(safe-area-inset-bottom) env(safe-area-inset-left);
      background: #FAFCF7;
      color: #1A2E1E;
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    header.viewer-header {
      background: #7FB069;
      color: #fff;
      padding: 1rem;
      text-align: center;
    }
    header.viewer-header h1 {
      margin: 0;
      font-size: 1.25rem;
      font-weight: 700;
    }
    .error-card {
      margin: 2rem auto;
      max-width: 480px;
      width: 90%;
      background: #fff;
      border-radius: 12px;
      padding: 2rem;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,.08);
    }
    .error-code {
      font-size: 3rem;
      font-weight: 700;
      color: #7FB069;
      margin-bottom: .5rem;
    }
    .error-message {
      font-size: 1rem;
      color: #4A5C4E;
      line-height: 1.6;
    }
    @media (prefers-color-scheme: dark) {
      body { background: #0F1612; color: #E8F0EA; }
      .error-card { background: #1A241E; }
      .error-message { color: #9AAA9F; }
    }
  </style>
</head>
<body>
  <header class="viewer-header">
    <h1>라운드온</h1>
  </header>
  <main>
    <div class="error-card">
      <p class="error-code">${opts.statusCode}</p>
      <p class="error-message">${escapeHtml(opts.message)}</p>
    </div>
  </main>
</body>
</html>`;
}

/**
 * 410 만료 HTML
 */
export function render410(): string {
  return baseHtml({
    title: "라운드 만료",
    message: "이 라운드는 만료되었습니다. (생성 후 7일 경과)",
    statusCode: 410,
  });
}

/**
 * 404 미존재 HTML
 */
export function render404(): string {
  return baseHtml({
    title: "라운드 없음",
    message: "라운드를 찾을 수 없습니다.",
    statusCode: 404,
  });
}

/**
 * 429 Rate limit HTML
 */
export function render429(): string {
  return baseHtml({
    title: "요청 한도 초과",
    message: "요청 한도를 초과했습니다. 잠시 후 다시 시도하세요.",
    statusCode: 429,
  });
}

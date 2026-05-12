/**
 * PIN 잠금 화면 HTML
 * 31-VIEWER_HTML §8, 33-SECURITY §5.3
 */

import { escapeHtml } from "../lib/escape.js";
import type { ShareMeta } from "../types.js";

/**
 * PIN 잠금 화면 렌더링
 */
export function renderPinLock(shortId: string, meta: ShareMeta): string {
  const courseName = escapeHtml(
    meta.round.courseName || "코스 정보 없음"
  );
  const roundDate = escapeHtml(meta.round.date || "");

  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="theme-color" content="#7FB069" />
  <title>PIN 확인 — 라운드온</title>
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
    }
    header.viewer-header h1 {
      margin: 0 0 .25rem;
      font-size: 1.25rem;
      font-weight: 700;
    }
    header.viewer-header .round-meta {
      margin: 0;
      font-size: .875rem;
      opacity: .85;
    }
    .pin-card {
      margin: 2rem auto;
      max-width: 480px;
      width: 90%;
      background: #fff;
      border-radius: 12px;
      padding: 2rem;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,.08);
    }
    .pin-card h2 {
      margin: 0 0 .5rem;
      font-size: 1.125rem;
      color: #1A2E1E;
    }
    .pin-card p {
      margin: 0 0 1.5rem;
      font-size: .9rem;
      color: #4A5C4E;
    }
    #pin-form {
      display: flex;
      flex-direction: column;
      gap: .75rem;
    }
    #pin-input {
      width: 100%;
      padding: .75rem 1rem;
      border: 1.5px solid #C8DCC0;
      border-radius: 8px;
      font-size: 1.25rem;
      text-align: center;
      letter-spacing: .25em;
      min-height: 44px;
      outline: none;
      background: #FAFCF7;
    }
    #pin-input:focus {
      border-color: #7FB069;
    }
    button[type="submit"] {
      background: #7FB069;
      color: #fff;
      border: none;
      border-radius: 8px;
      padding: .75rem;
      font-size: 1rem;
      font-weight: 600;
      min-height: 44px;
      cursor: pointer;
    }
    button[type="submit"]:active {
      background: #5A8A6B;
    }
    .pin-msg {
      margin-top: .75rem;
      font-size: .875rem;
      color: #D94444;
    }
    @media (prefers-color-scheme: dark) {
      body { background: #0F1612; color: #E8F0EA; }
      .pin-card { background: #1A241E; }
      .pin-card h2 { color: #E8F0EA; }
      .pin-card p { color: #9AAA9F; }
      #pin-input { background: #0F1612; color: #E8F0EA; border-color: #2A3530; }
    }
  </style>
</head>
<body>
  <header class="viewer-header">
    <h1>${courseName}</h1>
    <p class="round-meta">${roundDate}</p>
  </header>
  <main>
    <section class="pin-card">
      <h2>PIN 확인</h2>
      <p>이 라운드는 PIN으로 보호되어 있습니다.</p>
      <form id="pin-form" autocomplete="off">
        <!-- type="text"+inputmode="numeric": iOS/Android 숫자 키보드 + maxlength 동작 (31-VIEWER §8) -->
        <input id="pin-input" type="text" inputmode="numeric" maxlength="4"
               placeholder="4자리 숫자 입력" autocomplete="off" pattern="[0-9]{4}"
               required style="min-height:44px;" aria-label="PIN 4자리 입력" />
        <button type="submit" style="min-height:44px;">확인</button>
      </form>
      <p id="pin-error"  class="pin-msg" hidden aria-live="polite">PIN이 일치하지 않습니다. (1/5)</p>
      <p id="pin-locked" class="pin-msg" hidden aria-live="polite">5회 오답으로 1시간 잠금되었습니다.</p>
    </section>
  </main>
  <script>
  (function () {
    document.getElementById('pin-form').addEventListener('submit', function (e) {
      e.preventDefault();
      var pin = document.getElementById('pin-input').value;
      if (!/^[0-9]{4}$/.test(pin)) {
        var errEl = document.getElementById('pin-error');
        errEl.textContent = 'PIN은 4자리 숫자여야 합니다.';
        errEl.hidden = false;
        return;
      }
      /*
       * PIN 검증 엔드포인트: POST /:shortId/verify-pin (33-SECURITY §5.3 정식 확정)
       * credentials: 'include' — 세션 쿠키(viewer_session) 자동 전송·저장에 필수 (31-VIEWER §8)
       */
      fetch('/${escapeHtml(shortId)}/verify-pin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ pin: pin })
      })
        .then(function (r) { return r.json().then(function (d) { return { status: r.status, data: d }; }); })
        .then(function (res) {
          var d = res.data;
          if (res.status === 200 && d.ok) {
            // 200: 세션 쿠키 브라우저 자동 저장 완료 → viewer 본문 로드
            window.location.reload();
          } else if (res.status === 429 && d.locked) {
            // 429: 5회 오답 잠금
            document.getElementById('pin-locked').hidden = false;
            document.getElementById('pin-error').hidden  = true;
          } else {
            // 401: PIN 불일치 — attempts 카운트 표시
            var el = document.getElementById('pin-error');
            el.textContent = 'PIN이 일치하지 않습니다. (' + (d.attempts != null ? d.attempts : '?') + '/5)';
            el.hidden = false;
          }
        })
        .catch(function () {
          var el = document.getElementById('pin-error');
          el.textContent = '오류가 발생했습니다. 다시 시도해 주세요.';
          el.hidden = false;
        });
    });
  }());
  </script>
</body>
</html>`;
}

/**
 * viewer HTML — 정상 (200 공개) 렌더링
 * 31-VIEWER_HTML §2~§7 전체 구현
 *
 * 구조:
 *  - 헤더 (코스명, 날짜, 플레이어)
 *  - 스코어카드 (9홀 2단 — OUT/IN)
 *  - 사진 갤러리 (3열 그리드 + ZIP 다운로드)
 *  - 라이트박스 (풀스크린 뷰어 + 스와이프 + 핀치줌)
 *  - 푸터 (만료 시각 + OSM ODbL 크레딧)
 */

import { escapeHtml, escapeJsonForScript } from "../lib/escape.js";
import type { ShareMeta, Photo, Hole, Player } from "../types.js";

// ── 점수 셀 CSS 클래스 (31-VIEWER §4) ─────────────────────────────────────

function scoreClass(shots: number, par: number): string {
  const diff = shots - par;
  if (diff <= -2) return "eagle";
  if (diff === -1) return "birdie";
  if (diff === 0) return "par";
  if (diff === 1) return "bogey";
  return "double-plus";
}

// ── 스코어카드 OUT/IN 반절 렌더링 ─────────────────────────────────────────

function renderScorecardHalf(
  label: string,
  holes: Hole[],
  players: Player[]
): string {
  const playerHeaders = players
    .map((p) => `<th>${escapeHtml(p.name)}</th>`)
    .join("");

  const rows = holes
    .map((hole) => {
      const cells = players
        .map((player) => {
          const score = hole.scores.find((s) => s.playerId === player.id);
          if (!score) return "<td>—</td>";
          const cls = scoreClass(score.shots, hole.par);
          return `<td class="${cls}">${score.shots}</td>`;
        })
        .join("");
      return `<tr><td>${hole.number}</td><td>${hole.par}</td>${cells}</tr>`;
    })
    .join("\n");

  // 합계
  const totals = players
    .map((player) => {
      const sum = holes.reduce((acc, hole) => {
        const score = hole.scores.find((s) => s.playerId === player.id);
        return acc + (score?.shots ?? 0);
      }, 0);
      return `<td>${sum}</td>`;
    })
    .join("");

  return `
  <div class="scorecard-half">
    <table class="score-table">
      <thead>
        <tr>
          <th>홀</th><th>Par</th>${playerHeaders}
        </tr>
      </thead>
      <tbody>
        ${rows}
      </tbody>
      <tfoot class="sticky-total">
        <tr><td colspan="2">${label}</td>${totals}</tr>
      </tfoot>
    </table>
  </div>`;
}

// ── 사진 갤러리 렌더링 (31-VIEWER §5) ─────────────────────────────────────

interface PhotoViewItem {
  src: string;
  downloadSrc: string;
  alt: string;
  filename: string;
}

function renderGallery(
  shortId: string,
  photos: Photo[],
  domain: string
): { html: string; photoItems: PhotoViewItem[] } {
  if (photos.length === 0) {
    return {
      html: `
  <section class="photo-gallery">
    <p class="gallery-empty">이 라운드에 첨부된 사진이 없습니다.</p>
  </section>`,
      photoItems: [],
    };
  }

  const photoItems: PhotoViewItem[] = photos.map((photo, i) => ({
    src: `https://${domain}/${shortId}/photo/${photo.photoId}`,
    downloadSrc: `https://${domain}/${shortId}/photo/${photo.photoId}?download=1`,
    alt: photo.caption
      ? escapeHtml(photo.caption)
      : photo.holeNumber
      ? `홀 ${photo.holeNumber} 사진`
      : `라운드 사진 ${i + 1}`,
    filename: `golf-${shortId}-${i + 1}.jpg`,
  }));

  const figures = photos
    .map((photo, i) => {
      const item = photoItems[i];
      return `
      <figure class="photo-item" data-photo-id="${escapeHtml(photo.photoId)}" data-index="${i}">
        <!-- iOS long-press "사진에 저장": <img> 직접 표시 필수 (31-VIEWER §6 MUST) -->
        <img
          src="${escapeHtml(item.src)}"
          alt="${escapeHtml(item.alt)}"
          loading="lazy"
          style="touch-action: pinch-zoom;"
        />
      </figure>`;
    })
    .join("\n");

  const html = `
  <section class="photo-gallery">
    <div class="photo-grid">
      ${figures}
    </div>
    <!-- ZIP 다운로드 (30-API §6.4) -->
    <a class="btn-zip-download"
       href="https://${domain}/${shortId}/photos.zip"
       download="roundon-${escapeHtml(shortId)}.zip">
      사진 전체 다운로드 (ZIP)
    </a>
  </section>`;

  return { html, photoItems };
}

// ── 메인 viewer HTML 렌더링 ────────────────────────────────────────────────

export interface ViewerRenderOptions {
  shortId: string;
  meta: ShareMeta;
  domain: string;
}

export function renderViewer(opts: ViewerRenderOptions): string {
  const { shortId, meta, domain } = opts;
  const { round, options, expiresAt, photos } = meta;

  // 플레이어 이름 처리: nameVisibility (31-VIEWER §3)
  const displayPlayers: Player[] = round.players.map((p, i) => ({
    ...p,
    name:
      options.nameVisibility === "anonymous"
        ? String.fromCharCode(65 + i) // A, B, C, D
        : p.name,
  }));

  // 헤더 플레이어 표시
  const playerLabel =
    displayPlayers.length === 0
      ? ""
      : displayPlayers.length === 1
      ? escapeHtml(displayPlayers[0].name)
      : `${escapeHtml(displayPlayers[0].name)} 외 ${displayPlayers.length - 1}명`;

  const courseName = escapeHtml(round.courseName || "코스 정보 없음");
  const roundDate = escapeHtml(round.date || "");
  const dataQuality = round.dataQuality ?? "low";

  // 스코어카드 — 9홀 2단
  const allHoles = round.holes ?? [];
  const outHoles = allHoles.filter((h) => h.number >= 1 && h.number <= 9);
  const inHoles = allHoles.filter((h) => h.number >= 10 && h.number <= 18);

  const scorecardOut = outHoles.length > 0
    ? renderScorecardHalf("OUT", outHoles, displayPlayers)
    : "";
  const scorecardIn = inHoles.length > 0
    ? renderScorecardHalf("IN", inHoles, displayPlayers)
    : "";

  // 사진 갤러리
  const { html: galleryHtml, photoItems } = renderGallery(
    shortId,
    photos ?? [],
    domain
  );

  // __PHOTOS__ JSON (라이트박스용 — 31-VIEWER §7)
  const photosJson = escapeJsonForScript(photoItems);

  // 만료 시각 표시
  const expiresAtDisplay = escapeHtml(expiresAt);

  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <!-- viewport-fit=cover: safe-area-inset 요구 충족 (spec_3.md:149) -->
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="theme-color" content="#7FB069" />
  <title>${courseName} — 라운드온</title>
  <!-- robots: 검색 인덱싱 차단 (개인 라운드 데이터 보호) -->
  <meta name="robots" content="noindex, nofollow" />
  <style>
    *, *::before, *::after { box-sizing: border-box; }

    /* CSS 변수 — Spring 팔레트 (10-DESIGN_SYSTEM §2) */
    :root {
      --green-primary: #7FB069;
      --green-secondary: #C8DCC0;
      --green-accent:  #4A7A58;
      --surface: #FAFCF7;
      --surface-elevated: #FFFFFF;
      --text-primary: #1A2E1E;
      --text-secondary: #4A5C4E;
      --border: #C8DCC0;
    }

    body {
      margin: 0;
      font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif;
      padding: env(safe-area-inset-top) env(safe-area-inset-right)
               env(safe-area-inset-bottom) env(safe-area-inset-left);
      background: var(--surface);
      color: var(--text-primary);
    }

    /* 헤더 */
    .viewer-header {
      background: var(--green-primary);
      color: #fff;
      padding: 1rem;
    }
    .course-name {
      margin: 0 0 .25rem;
      font-size: 1.25rem;
      font-weight: 700;
    }
    .round-meta {
      margin: 0;
      font-size: .875rem;
      opacity: .85;
    }

    /* 데이터 품질 배지 (31-VIEWER §3, CLAUDE.md §PROJECT) */
    .data-quality-badge[data-quality="low"] {
      font-size: .8rem;
      color: var(--text-secondary);
      background: var(--green-secondary);
      padding: .375rem .75rem;
      border-top: 1px solid var(--border);
      text-align: center;
    }

    /* 스코어카드 */
    .scorecard {
      padding: 1rem;
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }
    .scorecard-half {
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
    }
    .score-table {
      width: 100%;
      border-collapse: collapse;
      font-size: .875rem;
      min-width: 280px;
    }
    .score-table th, .score-table td {
      padding: .5rem .375rem;
      text-align: center;
      border-bottom: 1px solid var(--border);
      min-width: 44px; min-height: 44px; /* 터치 타깃 44pt (spec_3.md:150) */
    }
    .score-table thead th {
      background: var(--green-secondary);
      font-weight: 600;
      position: sticky;
      top: 0;
    }
    /* sticky-total: 합계 행 (31-VIEWER §4) */
    .sticky-total {
      position: sticky;
      bottom: 0;
    }
    .sticky-total td {
      background: var(--surface-elevated);
      font-weight: 700;
      border-top: 2px solid var(--green-primary);
    }

    /* 점수 셀 색상 (31-VIEWER §4 매트릭스) */
    .eagle     { background: #2E7D32; color: #fff; border-radius: 50%; }
    .birdie    { background: var(--green-primary); color: #fff; border-radius: 50%; }
    .par       { /* 기본 */ }
    .bogey     { background: #EEF0ED; color: var(--text-primary); border-radius: 2px; }
    .double-plus { background: #D0D4CF; color: var(--text-primary); border-radius: 2px; }

    /* 사진 갤러리 */
    .photo-gallery {
      padding: 1rem;
    }
    .photo-gallery h2 {
      font-size: 1rem;
      font-weight: 700;
      margin: 0 0 .75rem;
    }
    .photo-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px; /* 10-DESIGN_SYSTEM §4 간격 토큰 */
    }
    .photo-item {
      margin: 0;
      padding: 0;
      cursor: pointer;
    }
    .photo-item img {
      width: 100%;
      aspect-ratio: 1;
      object-fit: cover;
      display: block;
      border-radius: 4px;
    }
    .gallery-empty {
      color: var(--text-secondary);
      text-align: center;
      padding: 2rem 0;
      font-size: .9rem;
    }
    .btn-zip-download {
      display: block;
      margin-top: 1rem;
      padding: .75rem;
      background: var(--green-primary);
      color: #fff;
      text-align: center;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      min-height: 44px;
      line-height: 1.5;
    }

    /* 푸터 */
    .viewer-footer {
      padding: 1.5rem 1rem;
      border-top: 1px solid var(--border);
      text-align: center;
      font-size: .75rem;
      color: var(--text-secondary);
    }
    .viewer-footer p { margin: .25rem 0; }

    /* 라이트박스 */
    #lightbox {
      position: fixed; inset: 0;
      background: rgba(0,0,0,.92);
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      z-index: 9999;
      padding: env(safe-area-inset-top) env(safe-area-inset-right)
               env(safe-area-inset-bottom) env(safe-area-inset-left);
    }
    #lb-close {
      position: absolute; top: 1rem; right: 1rem;
      background: none; border: none; color: #fff;
      font-size: 1.5rem; min-width: 44px; min-height: 44px;
      cursor: pointer;
    }
    #lb-img {
      max-width: 100%; max-height: 80vh;
      object-fit: contain; display: block;
      touch-action: pinch-zoom;
    }
    #lb-download {
      color: #fff; min-height: 44px;
      display: inline-flex; align-items: center;
      margin-top: .75rem;
      text-decoration: none;
      font-size: .9rem;
    }

    /* 다크 모드 — Winter 팔레트 (31-VIEWER §9, 10-DESIGN_SYSTEM §2) */
    @media (prefers-color-scheme: dark) {
      :root {
        --green-primary: #5A8A6B; --green-secondary: #2A3F35;
        --green-accent: #8FB5A0; --surface: #0F1612;
        --surface-elevated: #1A241E; --text-primary: #E8F0EA;
        --text-secondary: #9AAA9F; --border: #2A3530;
      }
      .eagle  { background: #388E3C; }
      .birdie { background: #5A8A6B; }
      .bogey  { background: #2A3530; }
      .double-plus { background: #1E2B22; }
    }
  </style>
</head>
<body>
  <header class="viewer-header">
    <h1 class="course-name">${courseName}</h1>
    <p class="round-meta">${roundDate}${playerLabel ? " · " + playerLabel : ""}</p>
  </header>

  ${
    dataQuality === "low"
      ? `<div class="data-quality-badge" data-quality="low">
    GPS 홀 자동 감지가 지원되지 않는 코스입니다.
  </div>`
      : ""
  }

  <main>
    <!-- 스코어카드 (31-VIEWER §4: 9홀 2단 디폴트) -->
    <section class="scorecard">
      ${scorecardOut}
      ${scorecardIn}
    </section>

    <!-- 사진 갤러리 (31-VIEWER §5) -->
    ${galleryHtml}
  </main>

  <!-- 푸터 (31-VIEWER §3, OSM ODbL 필수) -->
  <footer class="viewer-footer">
    <p class="expires-at">이 링크는 ${expiresAtDisplay}에 만료됩니다.</p>
    <!-- OSM ODbL 표기 (CLAUDE.md §PROJECT, golf-db-pack/README.md) -->
    <p class="osm-credit">&copy; OpenStreetMap contributors, ODbL 1.0</p>
  </footer>

  <!-- 라이트박스 (31-VIEWER §7) -->
  <div id="lightbox" hidden aria-modal="true" role="dialog">
    <button id="lb-close" aria-label="닫기">&#x2715;</button>
    <!-- display:block 필수 — background-image 미사용 (31-VIEWER §6 MUST) -->
    <img id="lb-img" alt="라운드 사진" aria-live="polite" />
    <a id="lb-download" download>사진 저장</a>
  </div>

  <script>
  /* window.__PHOTOS__: Worker 인라인 주입 (31-VIEWER §7) */
  window.__PHOTOS__ = ${photosJson};
  </script>
  <script>
  (function () {
    var photos = window.__PHOTOS__ || [];
    var cur = 0, startX = null, lastTrigger = null;
    var lb  = document.getElementById('lightbox');
    var img = document.getElementById('lb-img');
    var dl  = document.getElementById('lb-download');

    function open(i, trigger) {
      cur = i; var p = photos[i];
      img.src = p.src; img.alt = p.alt || '라운드 사진';
      dl.href = p.downloadSrc; dl.download = p.filename || 'golf-photo.jpg';
      lb.hidden = false; document.body.style.overflow = 'hidden';
      lastTrigger = trigger || null;
      document.getElementById('lb-close').focus();
    }
    function close() {
      lb.hidden = true; document.body.style.overflow = '';
      if (lastTrigger) lastTrigger.focus();
    }
    function nav(d) {
      var n = cur + (d === 'next' ? 1 : -1);
      if (n >= 0 && n < photos.length) open(n, lastTrigger);
    }

    document.querySelectorAll('.photo-item').forEach(function (el) {
      el.addEventListener('click', function () { open(+el.dataset.index, el); });
    });

    /* touchstart/touchend 방향 판정 — 핀치 줌과 충돌 회피 (31-VIEWER §7) */
    lb.addEventListener('touchstart', function (e) {
      if (e.touches.length > 1) { startX = null; return; }
      startX = e.touches[0].clientX;
    });
    lb.addEventListener('touchend', function (e) {
      if (startX === null || e.changedTouches.length > 1) return;
      var dx = e.changedTouches[0].clientX - startX;
      if (Math.abs(dx) > 50) nav(dx < 0 ? 'next' : 'prev');
      startX = null;
    });

    document.getElementById('lb-close').addEventListener('click', close);
    lb.addEventListener('click', function (e) { if (e.target === lb) close(); });
    /* ESC 키 닫기 (31-VIEWER §7) */
    document.addEventListener('keydown', function (e) {
      if (!lb.hidden && e.key === 'Escape') close();
    });
  }());
  </script>
</body>
</html>`;
}

/**
 * viewer HTML — 정상 (200 공개) 렌더링
 * 31-VIEWER_HTML §2~§4 구현 (사진 갤러리/라이트박스는 2026-05-18 폐기)
 *
 * 구조:
 *  - 헤더 (코스명, 날짜, 플레이어)
 *  - 스코어카드 (9홀 2단 — OUT/IN)
 *  - 푸터 (만료 시각 + OSM ODbL 크레딧)
 */

import { escapeHtml } from "../lib/escape.js";
import type { ShareMeta, Hole, Player } from "../types.js";

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

// ── KST 시각 포맷터 ─────────────────────────────────────────────────────
// 입력: ISO 8601 UTC 문자열 (예: "2026-05-25T02:35:33.176Z")
// 출력: "2026-05-25 11:35 (KST)"
function formatKST(isoUtc: string): string {
  const d = new Date(isoUtc);
  if (isNaN(d.getTime())) return isoUtc;
  // UTC + 9시간
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const Y = kst.getUTCFullYear();
  const M = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const D = String(kst.getUTCDate()).padStart(2, "0");
  const h = String(kst.getUTCHours()).padStart(2, "0");
  const m = String(kst.getUTCMinutes()).padStart(2, "0");
  return `${Y}-${M}-${D} ${h}:${m} (KST)`;
}

// ── 메인 viewer HTML 렌더링 ────────────────────────────────────────────────

export interface ViewerRenderOptions {
  shortId: string;
  meta: ShareMeta;
  domain: string;
}

export function renderViewer(opts: ViewerRenderOptions): string {
  const { meta } = opts;
  const { round, options, expiresAt } = meta;

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

  // 만료 시각 표시 — KST (UTC+9) 변환, "2026-05-25 02:35 (KST)" 형식
  const expiresAtDisplay = escapeHtml(formatKST(expiresAt));

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

    /* 푸터 */
    .viewer-footer {
      padding: 1.5rem 1rem;
      border-top: 1px solid var(--border);
      text-align: center;
      font-size: .75rem;
      color: var(--text-secondary);
    }
    .viewer-footer p { margin: .25rem 0; }

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
  </main>

  <!-- 푸터 (31-VIEWER §3, OSM ODbL 필수) -->
  <footer class="viewer-footer">
    <p class="expires-at">이 링크는 ${expiresAtDisplay}에 만료됩니다.</p>
    <!-- OSM ODbL 표기 (CLAUDE.md §PROJECT, golf-db-pack/README.md) -->
    <p class="osm-credit">&copy; OpenStreetMap contributors, ODbL 1.0</p>
  </footer>
</body>
</html>`;
}

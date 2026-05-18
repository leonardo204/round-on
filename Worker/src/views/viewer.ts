/**
 * viewer HTML — 정상 (200 공개) 렌더링
 * 디자인: Ref-docs/design-mockup/2026-05-18_viewer_redesign.html (B안)
 *
 * 구조:
 *  - 헤더 (그린 그라데이션 + 코스명, 날짜, 플레이어)
 *  - 데이터 품질 배지 (low인 경우만)
 *  - Hero 합계 카드 (플레이어별 총 타수 + par diff)
 *  - 스코어카드 (OUT/IN 미니 테이블 2단)
 *  - 푸터 (만료 시각 KST + OSM ODbL + 라운드온 브랜드)
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

// ── 스코어카드 OUT/IN 반절 렌더링 (B안 미니 테이블) ────────────────────────

function renderScorecardHalf(
  label: string,
  holes: Hole[],
  players: Player[]
): string {
  // 홀 번호 헤더 행
  const holeNumberCells = holes
    .map((h) => `<th>${h.number}</th>`)
    .join("");

  // par 헤더 행
  const parCells = holes
    .map((h) => `<th>${h.par}</th>`)
    .join("");

  const parTotal = holes.reduce((acc, h) => acc + h.par, 0);

  // 플레이어별 행
  const playerRows = players
    .map((player) => {
      const cells = holes
        .map((hole) => {
          const score = hole.scores.find((s) => s.playerId === player.id);
          if (!score || score.shots === 0) {
            return `<td><span class="cell empty">—</span></td>`;
          }
          const cls = scoreClass(score.shots, hole.par);
          // par는 plain (background 없음 — 칼라 매트릭스 정확 적용)
          if (cls === "par") {
            return `<td>${score.shots}</td>`;
          }
          return `<td><span class="cell ${cls}">${score.shots}</span></td>`;
        })
        .join("");

      const sum = holes.reduce((acc, hole) => {
        const score = hole.scores.find((s) => s.playerId === player.id);
        return acc + (score?.shots ?? 0);
      }, 0);
      const sumDisplay = sum > 0 ? `<strong>${sum}</strong>` : "—";

      return `<tr>
        <td class="col-label">${escapeHtml(player.name)}</td>
        ${cells}
        <td class="col-sum">${sumDisplay}</td>
      </tr>`;
    })
    .join("\n");

  return `
    <div class="card scorecard-section">
      <table class="score-table">
        <thead>
          <tr>
            <th class="col-label">${escapeHtml(label)}</th>
            ${holeNumberCells}
            <th class="col-sum">합</th>
          </tr>
          <tr class="par-row">
            <th class="col-label">Par</th>
            ${parCells}
            <th class="col-sum">${parTotal}</th>
          </tr>
        </thead>
        <tbody>
          ${playerRows}
        </tbody>
      </table>
    </div>`;
}

// ── Hero 카드 렌더링 (플레이어별 총 타수 + par diff) ───────────────────────

function renderHero(holes: Hole[], players: Player[]): string {
  const totalPar = holes.reduce((acc, h) => acc + h.par, 0);

  const blocks = players
    .map((player) => {
      const sum = holes.reduce((acc, hole) => {
        const score = hole.scores.find((s) => s.playerId === player.id);
        return acc + (score?.shots ?? 0);
      }, 0);
      const diff = sum - totalPar;
      let diffLabel = "—";
      let diffClass = "even";
      if (sum > 0) {
        if (diff === 0) { diffLabel = "E"; diffClass = "even"; }
        else if (diff > 0) { diffLabel = `+${diff}`; diffClass = "over"; }
        else { diffLabel = `${diff}`; diffClass = "under"; }
      }
      const sumDisplay = sum > 0 ? `${sum}` : "—";
      return `
        <div class="player-block">
          <div class="p-name">${escapeHtml(player.name)}</div>
          <div class="p-total">${sumDisplay}</div>
          <div class="p-vs-par ${diffClass}">${diffLabel}</div>
        </div>`;
    })
    .join("");

  return `<div class="card hero">${blocks}</div>`;
}

// ── KST 시각 포맷터 ─────────────────────────────────────────────────────

function formatKST(isoUtc: string): string {
  const d = new Date(isoUtc);
  if (isNaN(d.getTime())) return isoUtc;
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const Y = kst.getUTCFullYear();
  const M = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const D = String(kst.getUTCDate()).padStart(2, "0");
  const h = String(kst.getUTCHours()).padStart(2, "0");
  const m = String(kst.getUTCMinutes()).padStart(2, "0");
  return `${Y}-${M}-${D} ${h}:${m} (KST)`;
}

function formatKSTDate(isoUtc: string): string {
  const d = new Date(isoUtc);
  if (isNaN(d.getTime())) return isoUtc;
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const Y = kst.getUTCFullYear();
  const M = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const D = String(kst.getUTCDate()).padStart(2, "0");
  return `${Y}-${M}-${D}`;
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
        ? String.fromCharCode(65 + i)
        : p.name,
  }));

  const playerLabel =
    displayPlayers.length === 0
      ? ""
      : displayPlayers.length === 1
      ? escapeHtml(displayPlayers[0].name)
      : `${escapeHtml(displayPlayers[0].name)} 외 ${displayPlayers.length - 1}명`;

  const courseName = escapeHtml(round.courseName || "코스 정보 없음");
  const roundDate = round.date ? escapeHtml(formatKSTDate(round.date)) : "";
  const dataQuality = round.dataQuality ?? "low";

  const allHoles = round.holes ?? [];
  const outHoles = allHoles.filter((h) => h.number >= 1 && h.number <= 9);
  const inHoles = allHoles.filter((h) => h.number >= 10 && h.number <= 18);

  const heroHtml = renderHero(allHoles, displayPlayers);

  const scorecardOut = outHoles.length > 0
    ? renderScorecardHalf("전반", outHoles, displayPlayers)
    : "";
  const scorecardIn = inHoles.length > 0
    ? renderScorecardHalf("후반", inHoles, displayPlayers)
    : "";

  const expiresAtDisplay = escapeHtml(formatKST(expiresAt));

  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="theme-color" content="#2E7D32" />
  <title>${courseName} — 라운드온</title>
  <meta name="robots" content="noindex, nofollow" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --green-primary: #2E7D32;
      --green-light:   #43A047;
      --green-soft:    #66BB6A;
      --green-bg:      #C8DCC0;
      --surface:       #FAFCF7;
      --card:          #FFFFFF;
      --text-1:        #1A2E1E;
      --text-2:        #4A5C4E;
      --text-3:        #9AAA9F;
      --divider:       #EEF0ED;
      --red-soft:      #F4E1E1;
      --red-strong:    #E8B5B5;
      --red-text:      #C12525;
    }

    html, body {
      font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--surface);
      color: var(--text-1);
      -webkit-font-smoothing: antialiased;
    }
    body {
      padding: env(safe-area-inset-top) env(safe-area-inset-right)
               env(safe-area-inset-bottom) env(safe-area-inset-left);
    }

    /* ── 헤더 (그린 그라데이션) ────────────────────────────────────────── */
    .viewer-header {
      background: linear-gradient(135deg, var(--green-primary) 0%, var(--green-light) 100%);
      color: white;
      padding: 20px 20px 16px;
    }
    .course-name {
      font-size: 22px; font-weight: 800; letter-spacing: -0.5px;
    }
    .meta {
      font-size: 13px; opacity: 0.92; margin-top: 4px;
      display: flex; align-items: center; gap: 8px;
    }
    .meta-dot {
      width: 3px; height: 3px; border-radius: 50%;
      background: white; opacity: 0.7;
    }

    /* ── 데이터 품질 배지 ───────────────────────────────────────────── */
    .badge-low {
      padding: 8px 16px;
      font-size: 12px; color: var(--text-2);
      background: var(--divider); text-align: center;
      border-bottom: 1px solid #DCE0DA;
    }

    /* ── 카드 공통 ────────────────────────────────────────────────── */
    .card {
      background: var(--card);
      border-radius: 12px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.04);
    }

    /* ── Hero 합계 카드 ──────────────────────────────────────────── */
    .hero {
      margin: 16px;
      padding: 18px;
      display: flex; gap: 16px;
    }
    .player-block {
      flex: 1; text-align: center;
      border-right: 1px solid var(--divider);
    }
    .player-block:last-child { border-right: none; }
    .p-name {
      font-size: 12px; color: var(--text-2); font-weight: 600;
    }
    .p-total {
      font-size: 30px; font-weight: 800; margin-top: 4px;
      font-feature-settings: 'tnum'; color: var(--text-1);
    }
    .p-vs-par {
      font-size: 13px; font-weight: 600; margin-top: 2px;
    }
    .p-vs-par.under { color: var(--green-primary); }
    .p-vs-par.even  { color: var(--text-2); }
    .p-vs-par.over  { color: var(--red-text); }

    /* ── 스코어카드 영역 ───────────────────────────────────────────── */
    main { padding: 0 16px; }
    .scorecard-section {
      margin-top: 14px; overflow: hidden;
    }
    .score-table {
      width: 100%; border-collapse: collapse; font-size: 13px;
      font-feature-settings: 'tnum';
    }
    .score-table th, .score-table td {
      padding: 8px 4px; text-align: center;
      border-bottom: 1px solid var(--divider);
      min-width: 28px;
    }
    .score-table th.col-label, .score-table td.col-label {
      text-align: left; padding-left: 12px;
      color: var(--text-2); font-weight: 600; min-width: 56px;
    }
    .score-table thead th {
      background: var(--divider); color: var(--text-2);
      font-size: 11px; font-weight: 700;
    }
    .score-table thead tr.par-row th {
      background: var(--card); font-size: 10px;
      opacity: 0.7; padding-top: 4px; padding-bottom: 4px;
    }
    .score-table tbody td {
      color: var(--text-1); font-weight: 500;
    }
    .score-table .col-sum {
      color: var(--text-1); font-weight: 700;
    }

    /* ── 점수 셀 마커 (31-VIEWER §4 매트릭스) ─────────────────────── */
    .cell {
      display: inline-flex; align-items: center; justify-content: center;
      width: 26px; height: 26px; border-radius: 50%;
      font-feature-settings: 'tnum';
      font-weight: 700;
    }
    .cell.eagle   { background: #1B5E20; color: white; }
    .cell.birdie  { background: var(--green-soft); color: white; }
    .cell.bogey   { background: var(--red-soft); color: var(--text-1); border-radius: 6px; }
    .cell.double-plus { background: var(--red-strong); color: var(--text-1); border-radius: 6px; font-weight: 800; }
    .cell.empty   { color: var(--green-bg); font-weight: 400; }

    /* ── 푸터 ───────────────────────────────────────────────────── */
    .viewer-footer {
      padding: 18px 16px 24px;
      text-align: center;
      color: var(--text-3); font-size: 11px;
      border-top: 1px solid var(--divider);
      margin-top: 12px;
    }
    .viewer-footer .expire {
      color: var(--text-2); font-size: 12px;
      margin-bottom: 6px;
    }
    .viewer-footer .brand {
      font-size: 12px; color: var(--green-primary);
      font-weight: 600; margin-top: 6px;
    }

    /* ── 다크 모드 ──────────────────────────────────────────────── */
    @media (prefers-color-scheme: dark) {
      :root {
        --green-primary: #43A047;
        --green-light:   #66BB6A;
        --green-soft:    #5A8A6B;
        --green-bg:      #2A3F35;
        --surface:       #0F1612;
        --card:          #1A241E;
        --text-1:        #E8F0EA;
        --text-2:        #9AAA9F;
        --text-3:        #6E8071;
        --divider:       #2A3530;
        --red-soft:      #4A2A2A;
        --red-strong:    #6A2F2F;
        --red-text:      #E57373;
      }
      .cell.eagle  { background: #388E3C; }
      .cell.birdie { background: #5A8A6B; }
    }
  </style>
</head>
<body>
  <header class="viewer-header">
    <h1 class="course-name">${courseName}</h1>
    <div class="meta">
      <span>${roundDate}</span>
      ${playerLabel ? '<span class="meta-dot"></span><span>' + playerLabel + '</span>' : ''}
    </div>
  </header>

  ${
    dataQuality === "low"
      ? `<div class="badge-low">GPS 홀 자동 감지가 지원되지 않는 코스입니다.</div>`
      : ""
  }

  ${heroHtml}

  <main>
    ${scorecardOut}
    ${scorecardIn}
  </main>

  <footer class="viewer-footer">
    <div class="expire">🔒 ${expiresAtDisplay} 만료</div>
    <div>&copy; OpenStreetMap contributors, ODbL 1.0</div>
    <div class="brand">라운드온 · Round-On</div>
  </footer>
</body>
</html>`;
}

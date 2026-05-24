/**
 * viewer HTML — 정상 (200 공개) 렌더링
 *
 * 디자인: 2026-05-24 v6 — mockup 색/구조 유지 + 폰트 시스템 sans + 더블 2중 겹침 + 동점 1위 모두 leader
 *  - 폰트: 시스템 sans (Inter/Apple SD Gothic Neo) — Fraunces/Manrope 제거
 *  - 페이지 BG: #f4f7f4 + 좌상단/우하단 radial green wash
 *  - hero ::before 5px 그라데이션 라인 + ::after 우상단 240px radial glow
 *  - players 3카드: 동점 1위 모두 leader(green) 카드로 강조
 *  - bogey = mustard yellow tinted, double = terracotta solid + 외곽 ring 2중, par = green-700, birdie = terracotta border 원형
 *  - reveal 애니메이션 .d1~d5
 *  - 다크 모드 없음 (원본 mockup이 light only)
 *
 * 기능 유지: PIN/만료/PII 마스킹/9홀 라운드 안전 동작
 */

import { escapeHtml } from "../lib/escape.js";
import type { ShareMeta, Hole, Player } from "../types.js";

// ── 4단계 ScoreDiff 분류 ──────────────────────────────────────────────────

function scoreClass(shots: number, par: number): string {
  const diff = shots - par;
  if (diff <= -1) return "birdie";
  if (diff === 0) return "par";
  if (diff === 1) return "bogey";
  return "double";
}

// ── KST 시각 포맷터 ──────────────────────────────────────────────────────

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
  return `${Y} · ${M} · ${D}`;
}

// ── 점수 셀 렌더 헬퍼 ────────────────────────────────────────────────────

function renderScoreCell(
  shots: number,
  par: number,
  playerName: string,
  holeNumber: number
): string {
  if (shots === 0) {
    return `<td aria-label="${escapeHtml(playerName)} ${holeNumber}번홀 미입력"><span class="cell" style="opacity:0.35">—</span></td>`;
  }
  const cls = scoreClass(shots, par);
  const diff = shots - par;
  let diffLabel = "";
  if (diff <= -1) diffLabel = "버디 이상";
  else if (diff === 0) diffLabel = "파";
  else if (diff === 1) diffLabel = "보기";
  else diffLabel = "더블보기 이상";

  const ariaLabel = `${escapeHtml(playerName)} ${holeNumber}번홀 ${diffLabel} ${shots}타`;
  return `<td aria-label="${ariaLabel}"><span class="cell ${cls}">${shots}</span></td>`;
}

// ── 합계 diff 표시 헬퍼 ───────────────────────────────────────────────────

function diffDisplay(sum: number, totalPar: number): { label: string; cls: string } {
  const diff = sum - totalPar;
  if (diff === 0) return { label: "E", cls: "even" };
  if (diff > 0) return { label: `+${diff}`, cls: "over" };
  return { label: `${diff}`, cls: "under" };
}

// ── 9홀 카드 (전반/후반) 렌더링 ───────────────────────────────────────────

function renderHalfCard(
  holeGroup: Hole[],
  players: Player[],
  groupLabel: string,    // "OUT" | "IN"
  halfTitle: string,     // "전반 홀" | "후반 홀"
  groupPar: number,
  revealDelay: string,   // "d4" | "d5"
): string {
  const holeCols = holeGroup
    .map(
      (h) =>
        `<th><span class="hole-no">${h.number}</span><span class="hole-par">(${h.par})</span></th>`
    )
    .join("");

  const headerRow = `
    <tr>
      <th class="label-col">홀</th>
      ${holeCols}
      <th class="sum-col"><span class="hole-no">${groupLabel}</span><span class="hole-par">(${groupPar})</span></th>
    </tr>`;

  const playerRows = players
    .map((player) => {
      const cells = holeGroup
        .map((hole) => {
          const score = hole.scores.find((s) => s.playerId === player.id);
          return renderScoreCell(score?.shots ?? 0, hole.par, player.name, hole.number);
        })
        .join("");

      const groupSum = holeGroup.reduce((acc, hole) => {
        const score = hole.scores.find((s) => s.playerId === player.id);
        return acc + (score?.shots ?? 0);
      }, 0);

      let sumHtml: string;
      if (groupSum === 0) {
        sumHtml = `<td class="sum"><span class="sum-total">—</span></td>`;
      } else {
        const { label } = diffDisplay(groupSum, groupPar);
        sumHtml = `<td class="sum"><span class="sum-total">${groupSum}</span><span class="sum-delta">${label}</span></td>`;
      }

      return `
      <tr>
        <td class="player-label"><span class="swatch"></span>${escapeHtml(player.name)}</td>
        ${cells}
        ${sumHtml}
      </tr>`;
    })
    .join("\n");

  return `
  <section class="card reveal ${revealDelay}">
    <div class="card-head">
      <h2>${halfTitle}</h2>
      <span class="tag">${groupLabel} · Par ${groupPar}</span>
    </div>
    <div class="table-wrap">
      <table>
        <thead>${headerRow}</thead>
        <tbody>${playerRows}</tbody>
      </table>
    </div>
  </section>`;
}

// ── OUT/IN 분리 스코어카드 ───────────────────────────────────────────────

function renderScorecard(holes: Hole[], players: Player[]): string {
  const outHoles = holes.filter((h) => h.number >= 1 && h.number <= 9);
  const inHoles = holes.filter((h) => h.number >= 10 && h.number <= 18);

  const outPar = outHoles.reduce((a, h) => a + h.par, 0);
  const inPar = inHoles.reduce((a, h) => a + h.par, 0);

  const cards: string[] = [];
  if (outHoles.length > 0) cards.push(renderHalfCard(outHoles, players, "OUT", "전반 홀", outPar, "d4"));
  if (inHoles.length > 0) cards.push(renderHalfCard(inHoles, players, "IN", "후반 홀", inPar, "d5"));
  return cards.join("\n");
}

// ── Players 요약 카드 (leader = 동점 1위 전부) ───────────────────────────

function renderPlayers(holes: Hole[], players: Player[]): string {
  const totalPar = holes.reduce((acc, h) => acc + h.par, 0);

  const sums = players.map((player) => {
    const sum = holes.reduce((acc, hole) => {
      const score = hole.scores.find((s) => s.playerId === player.id);
      return acc + (score?.shots ?? 0);
    }, 0);
    return { player, sum };
  });

  const valid = sums.filter((s) => s.sum > 0);
  const minSum = valid.length ? Math.min(...valid.map((s) => s.sum)) : 0;
  const maxSum = valid.length ? Math.max(...valid.map((s) => s.sum)) : 0;

  // Tied rank (T1, T1, 3)
  const rankByPlayer = new Map<string, string>();
  const sortedValid = [...valid].sort((a, b) => a.sum - b.sum);
  {
    let i = 0;
    while (i < sortedValid.length) {
      const currentRank = i + 1;
      let j = i;
      while (j < sortedValid.length && sortedValid[j].sum === sortedValid[i].sum) j++;
      const tiedCount = j - i;
      const label = tiedCount > 1 ? `T${currentRank}` : `${currentRank}`;
      for (let k = i; k < j; k++) {
        rankByPlayer.set(sortedValid[k].player.id, label);
      }
      i = j;
    }
  }

  // leader: 동점 1위 모두 green gradient 카드로 강조
  const cards = sums.map(({ player, sum }, idx) => {
    const rank = rankByPlayer.get(player.id) ?? "";
    const isLeader = sum > 0 && sum === minSum;
    const leaderClass = isLeader ? "player-card leader" : "player-card";
    const delay = idx === 0 ? "d2" : idx === 1 ? "d3" : "d4";

    if (sum === 0) {
      return `
      <div class="${leaderClass} reveal ${delay}">
        <span class="rank">${escapeHtml(rank)}</span>
        <div class="player-name">${escapeHtml(player.name)}</div>
        <div class="player-score">
          <span class="total">—</span>
        </div>
        <div class="player-bar"><span style="width:0%"></span></div>
      </div>`;
    }

    const { label: deltaLabel } = diffDisplay(sum, totalPar);
    const barWidth = maxSum > 0 ? Math.round((sum / maxSum) * 100) : 0;

    return `
      <div class="${leaderClass} reveal ${delay}">
        <span class="rank">${escapeHtml(rank)}</span>
        <div class="player-name">${escapeHtml(player.name)}</div>
        <div class="player-score">
          <span class="total">${sum}</span>
          <span class="delta">${deltaLabel}</span>
        </div>
        <div class="player-bar"><span style="width:${barWidth}%"></span></div>
      </div>`;
  }).join("");

  return `<section class="players">${cards}</section>`;
}

// ── 메인 viewer HTML 렌더링 ───────────────────────────────────────────────

export interface ViewerRenderOptions {
  shortId: string;
  meta: ShareMeta;
  domain: string;
}

export function renderViewer(opts: ViewerRenderOptions): string {
  const { meta } = opts;
  const { round, options, expiresAt } = meta;

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

  const allHoles = round.holes ?? [];
  const totalPar = allHoles.reduce((a, h) => a + h.par, 0);

  const playersHtml = renderPlayers(allHoles, displayPlayers);
  const scorecardHtml = allHoles.length > 0 ? renderScorecard(allHoles, displayPlayers) : "";
  const expiresAtDisplay = escapeHtml(formatKST(expiresAt));

  return `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
<meta name="theme-color" content="#0f3d2e" />
<title>${courseName} · 라운드 스코어카드</title>
<meta name="robots" content="noindex, nofollow" />
<style>
  :root {
    --green-900: #0f3d2e;
    --green-800: #14492f;
    --green-700: #1c6b43;
    --green-600: #21895a;
    --green-500: #2da06a;
    --green-400: #4cb784;
    --green-100: #e3f3ea;
    --green-50:  #f1f9f4;
    --ink:       #1a2620;
    --ink-soft:  #5d6b63;
    --ink-faint: #94a39b;
    --paper:     #ffffff;
    --bg:        #f4f7f4;
    --line:      #e6ece7;
    --birdie:    #c0573a;

    --score-par:    #2da06a;
    --score-bogey:  #d6a93b;
    --score-double: #c0573a;
    --score-double-cell: #1e40af;  /* 스코어카드 더블 셀 전용 진한 블루 */
  }

  * { margin: 0; padding: 0; box-sizing: border-box; }

  html, body {
    background: var(--bg);
    font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Segoe UI", system-ui, sans-serif;
    color: var(--ink);
    -webkit-font-smoothing: antialiased;
  }

  body {
    background-image:
      radial-gradient(circle at 12% 8%, rgba(45,160,106,0.07), transparent 42%),
      radial-gradient(circle at 88% 95%, rgba(45,160,106,0.06), transparent 45%);
    min-height: 100vh;
    padding: 48px 20px 64px;
    padding-top: max(48px, env(safe-area-inset-top));
    padding-bottom: max(64px, env(safe-area-inset-bottom));
  }

  .shell {
    max-width: 980px;
    margin: 0 auto;
  }

  /* ---------- Header ---------- */
  .hero {
    position: relative;
    background: var(--paper);
    border-radius: 24px;
    padding: 40px 44px;
    overflow: hidden;
    box-shadow: 0 1px 2px rgba(15,61,46,0.04), 0 18px 40px -24px rgba(15,61,46,0.22);
    border: 1px solid var(--line);
  }
  .hero::before {
    content: "";
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 5px;
    background: linear-gradient(90deg, var(--green-700), var(--green-400), var(--green-600));
  }
  .hero::after {
    content: "";
    position: absolute;
    right: -60px; top: -60px;
    width: 240px; height: 240px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(45,160,106,0.10), transparent 70%);
  }
  .hero-eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--green-600);
    margin-bottom: 14px;
  }
  .hero-eyebrow .dot {
    width: 6px; height: 6px;
    border-radius: 50%;
    background: var(--green-500);
  }
  .hero h1 {
    font-family: inherit;
    font-size: 46px;
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--ink);
    line-height: 1.05;
  }
  .hero-meta {
    margin-top: 12px;
    display: flex;
    align-items: center;
    gap: 14px;
    font-size: 14.5px;
    color: var(--ink-soft);
    font-weight: 500;
    flex-wrap: wrap;
  }
  .hero-meta .sep {
    width: 4px; height: 4px;
    border-radius: 50%;
    background: var(--ink-faint);
  }

  /* ---------- Player summary (3-card hero) ---------- */
  .players {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
    margin-top: 18px;
  }
  .player-card {
    background: var(--paper);
    border: 1px solid var(--line);
    border-radius: 20px;
    padding: 24px 26px;
    position: relative;
    overflow: hidden;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
  }
  .player-card:hover {
    transform: translateY(-3px);
    box-shadow: 0 20px 38px -22px rgba(15,61,46,0.28);
  }
  .player-card.leader {
    background: linear-gradient(160deg, var(--green-700), var(--green-800));
    border-color: var(--green-700);
  }
  .player-card .rank {
    position: absolute;
    top: 18px; right: 20px;
    font-family: inherit;
    font-size: 13px;
    font-weight: 600;
    color: var(--ink-faint);
  }
  .player-card.leader .rank { color: rgba(255,255,255,0.55); }
  .player-name {
    font-size: 14px;
    font-weight: 700;
    color: var(--ink-soft);
    letter-spacing: 0.01em;
  }
  .player-card.leader .player-name { color: rgba(255,255,255,0.78); }
  .player-score {
    margin-top: 10px;
    display: flex;
    align-items: baseline;
    gap: 10px;
  }
  .player-score .total {
    font-family: inherit;
    font-size: 52px;
    font-weight: 600;
    line-height: 1;
    letter-spacing: -0.02em;
    color: var(--green-700);
    font-variant-numeric: tabular-nums;
  }
  .player-card.leader .player-score .total { color: #fff; }
  .player-score .delta {
    font-size: 16px;
    font-weight: 700;
    color: var(--score-double);
    font-variant-numeric: tabular-nums;
  }
  .player-card.leader .player-score .delta { color: var(--green-400); }
  .player-bar {
    margin-top: 16px;
    height: 6px;
    border-radius: 99px;
    background: var(--green-50);
    overflow: hidden;
  }
  .player-card.leader .player-bar { background: rgba(255,255,255,0.16); }
  .player-bar span {
    display: block;
    height: 100%;
    border-radius: 99px;
    background: linear-gradient(90deg, var(--green-500), var(--green-400));
  }
  .player-card.leader .player-bar span {
    background: linear-gradient(90deg, var(--green-400), #8fdcb6);
  }

  /* ---------- Scorecard table ---------- */
  .card {
    background: var(--paper);
    border: 1px solid var(--line);
    border-radius: 22px;
    margin-top: 18px;
    overflow: hidden;
    box-shadow: 0 1px 2px rgba(15,61,46,0.04);
  }
  .card-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 26px 14px;
  }
  .card-head h2 {
    font-family: inherit;
    font-size: 19px;
    font-weight: 600;
    color: var(--ink);
  }
  .card-head .tag {
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--green-600);
    background: var(--green-50);
    border: 1px solid var(--green-100);
    padding: 5px 11px;
    border-radius: 99px;
  }

  .table-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }

  table {
    width: 100%;
    border-collapse: collapse;
    min-width: 720px;
    font-variant-numeric: tabular-nums;
  }
  thead th {
    padding: 12px 6px 14px;
    text-align: center;
    font-weight: 700;
    background: var(--green-50);
    border-bottom: 1px solid var(--line);
  }
  thead th .hole-no {
    font-size: 22px;
    color: var(--ink);
    font-weight: 800;
  }
  thead th .hole-par {
    display: block;
    font-size: 16px;
    color: var(--ink-faint);
    font-weight: 600;
    margin-top: 3px;
  }
  thead th.label-col {
    text-align: left;
    padding-left: 26px;
    font-size: 21px;
    letter-spacing: 0.02em;
    color: var(--ink);
    font-weight: 700;
  }
  thead th.sum-col {
    background: var(--green-700);
    color: #fff;
  }
  thead th.sum-col .hole-no { color: #fff; }
  thead th.sum-col .hole-par { color: rgba(255,255,255,0.6); }

  tbody td {
    padding: 11px 6px;
    text-align: center;
    border-bottom: 1px solid var(--line);
  }
  tbody tr:last-child td { border-bottom: none; }
  tbody tr:nth-child(even) td { background: #fbfdfb; }

  td.player-label {
    text-align: left;
    padding-left: 26px;
    font-weight: 700;
    font-size: 14px;
    color: var(--ink);
    white-space: nowrap;
  }
  td.player-label .swatch {
    display: inline-block;
    width: 8px; height: 8px;
    border-radius: 2px;
    margin-right: 9px;
    vertical-align: middle;
    background: var(--green-500);
  }

  /* score cell */
  .cell {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 34px; height: 34px;
    font-size: 14.5px;
    font-weight: 700;
    border-radius: 9px;
    color: var(--ink);
  }
  .cell.birdie {
    color: var(--birdie);
    border: 1.6px solid var(--birdie);
    border-radius: 50%;
  }
  .cell.par {
    color: var(--green-700);
  }
  .cell.bogey {
    color: var(--score-bogey);
    border: 1.6px solid rgba(214,169,59,0.55);
    background: rgba(214,169,59,0.08);
  }
  /* double: 동심 이중 사각형 — inner border + outer ::before, 진한 블루 톤 */
  .cell.double {
    position: relative;
    color: var(--score-double-cell);
    background: transparent;
    border: 1px solid var(--score-double-cell);
    border-radius: 4px;
  }
  .cell.double::before {
    content: "";
    position: absolute;
    inset: -4px;
    border: 1px solid var(--score-double-cell);
    border-radius: 6px;
    pointer-events: none;
  }

  td.sum {
    background: var(--green-50);
    border-left: 1px solid var(--line);
  }
  td.sum .sum-total {
    font-family: inherit;
    font-size: 20px;
    font-weight: 600;
    color: var(--ink);
  }
  td.sum .sum-delta {
    display: block;
    font-size: 11px;
    font-weight: 700;
    color: var(--score-double);
    margin-top: 1px;
  }

  /* ---------- Legend ---------- */
  .legend {
    background: var(--paper);
    border: 1px solid var(--line);
    border-radius: 18px;
    margin-top: 18px;
    padding: 18px 26px;
    display: flex;
    flex-wrap: wrap;
    gap: 26px;
    align-items: center;
  }
  .legend-item {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 13px;
    color: var(--ink-soft);
    font-weight: 600;
  }
  .legend-chip {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 30px; height: 30px;
    font-size: 13px;
    font-weight: 700;
    border-radius: 8px;
  }
  .legend-chip.birdie { color: var(--birdie); border: 1.6px solid var(--birdie); border-radius: 50%; }
  .legend-chip.par { color: var(--green-700); }
  .legend-chip.bogey { color: var(--score-bogey); border: 1.6px solid rgba(214,169,59,0.55); background: rgba(214,169,59,0.08); }
  .legend-chip.double { position: relative; color: var(--score-double-cell); background: transparent; border: 1px solid var(--score-double-cell); border-radius: 4px; }
  .legend-chip.double::before { content: ""; position: absolute; inset: -4px; border: 1px solid var(--score-double-cell); border-radius: 6px; pointer-events: none; }

  /* ---------- Footer ---------- */
  footer {
    text-align: center;
    margin-top: 34px;
    color: var(--ink-faint);
    font-size: 12.5px;
    line-height: 1.9;
  }
  footer .brand {
    font-family: inherit;
    font-size: 15px;
    font-weight: 600;
    color: var(--green-700);
    margin-top: 4px;
  }

  /* ---------- Animations ---------- */
  .reveal {
    opacity: 0;
    transform: translateY(14px);
    animation: rise 0.6s cubic-bezier(0.22,1,0.36,1) forwards;
  }
  @keyframes rise {
    to { opacity: 1; transform: translateY(0); }
  }
  .d1 { animation-delay: 0.05s; }
  .d2 { animation-delay: 0.13s; }
  .d3 { animation-delay: 0.21s; }
  .d4 { animation-delay: 0.29s; }
  .d5 { animation-delay: 0.37s; }

  @media (max-width: 720px) {
    body { padding: 20px 10px 40px; }
    .hero { padding: 24px 18px; border-radius: 18px; }
    .hero h1 { font-size: 30px; }
    .hero-meta { font-size: 12.5px; gap: 10px; }

    /* 3-card hero — 모바일에서도 한 줄 fit */
    .players { gap: 8px; margin-top: 12px; }
    .player-card { padding: 14px 12px; border-radius: 14px; }
    .player-card .rank { top: 9px; right: 10px; font-size: 11px; }
    .player-name { font-size: 12px; }
    .player-score { margin-top: 6px; gap: 4px; }
    .player-score .total { font-size: 28px; }
    .player-score .delta { font-size: 12px; }
    .player-bar { margin-top: 10px; height: 4px; }

    /* 스코어카드 — device width fit (가로 스크롤 제거) */
    .card { border-radius: 16px; margin-top: 12px; }
    .card-head { padding: 16px 16px 8px; }
    .card-head h2 { font-size: 16px; }
    .card-head .tag { font-size: 10px; padding: 4px 9px; letter-spacing: 0.06em; }
    .table-wrap { overflow-x: hidden; }
    table { min-width: 0; }
    thead th { padding: 9px 1px; }
    thead th.label-col { padding-left: 10px; font-size: 13px; }
    thead th .hole-no { font-size: 14px; }
    thead th .hole-par { font-size: 10px; margin-top: 2px; }
    tbody td { padding: 8px 1px; }
    td.player-label { padding-left: 10px; font-size: 12.5px; }
    td.player-label .swatch { width: 6px; height: 6px; margin-right: 6px; border-radius: 1.5px; }
    .cell { width: 24px; height: 24px; font-size: 12px; border-radius: 6px; }
    .cell.birdie { width: 22px; height: 22px; border-width: 1.2px; }
    .cell.bogey { border-width: 1.2px; }
    .cell.double { border-radius: 4px; }
    .cell.double::before { inset: -3px; border-radius: 5px; border-width: 1px; }
    td.sum { padding: 8px 8px 8px 4px; }
    td.sum .sum-total { font-size: 16px; }
    td.sum .sum-delta { font-size: 9px; }

    .legend { padding: 14px 16px; gap: 14px; border-radius: 14px; }
    .legend-item { font-size: 12px; gap: 8px; }
    .legend-chip { width: 24px; height: 24px; font-size: 11px; }
    .legend-chip.double::before { inset: -3px; }
  }
</style>
</head>
<body>
<div class="shell">

  <!-- Hero -->
  <header class="hero reveal d1">
    <span class="hero-eyebrow"><span class="dot"></span>Round Scorecard</span>
    <h1>${courseName}</h1>
    <div class="hero-meta">
      ${roundDate ? `<span>${roundDate}</span>` : ""}
      ${roundDate && playerLabel ? `<span class="sep"></span>` : ""}
      ${playerLabel ? `<span>${playerLabel}</span>` : ""}
      ${totalPar > 0 ? `<span class="sep"></span><span>Par ${totalPar}</span>` : ""}
    </div>
  </header>

  ${playersHtml}

  ${scorecardHtml}

  <!-- Legend -->
  <div class="legend reveal d5">
    <div class="legend-item">
      <span class="legend-chip birdie">3</span>버디 이상 (≤ -1)
    </div>
    <div class="legend-item">
      <span class="legend-chip par">4</span>파 (E)
    </div>
    <div class="legend-item">
      <span class="legend-chip bogey">5</span>보기 (+1)
    </div>
    <div class="legend-item">
      <span class="legend-chip double">6</span>더블보기 이상 (≥ +2)
    </div>
  </div>

  <footer class="reveal d5">
    <div>만료 · ${expiresAtDisplay}</div>
    <div>© OpenStreetMap contributors, ODbL 1.0</div>
    <div class="brand">라운드온 · Round-On</div>
  </footer>

</div>
</body>
</html>`;
}

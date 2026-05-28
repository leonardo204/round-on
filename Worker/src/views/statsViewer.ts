/**
 * 통계 공유 viewer HTML 렌더러
 * 통계 공유 v1 (2026-05-27)
 *
 * - JS 최소화 (PIN 입력 폼만)
 * - 외부 폰트 없음 (시스템 폰트)
 * - 다크모드 비대응 v1
 * - 한국어 고정
 * - og:image: 제거 (v1) — 정적 PNG 자산 미배포 상태, 카톡은 og:title+og:description으로 폴백
 *   v2 todo: og:image 자산 추가 (satori 또는 정적 PNG 3장: og-stats-pr/hcp/trend.png)
 */

import { escapeHtml } from "../lib/escape.js";
import type {
  StatsShareMeta,
  StatsSharePayload,
  StatsParAverage,
  StatsRegionShare,
  StatsRoundLocationShare,
  StatsRecentEntryShare,
  StatsSignatureMiniStat,
} from "../types.js";

// ── D-day 계산 ────────────────────────────────────────────────────────────
// 당일 생성 → D-7, 다음날 → D-6, ..., 만료일 당일 → D-0
// 1일 미만 남은 경우 시간 표시

function calcDday(expiresAt: number): string {
  const diff = expiresAt - Date.now();
  if (diff <= 0) return "만료됨";
  // 하루 미만 남은 경우 시간 단위로 표시
  if (diff < 1000 * 60 * 60 * 24) {
    const hours = Math.ceil(diff / (1000 * 60 * 60));
    return hours <= 1 ? "오늘 만료" : `만료까지 ${hours}시간`;
  }
  // 하루 이상: Math.floor 사용 (당일=7, 다음날=6, ..., 만료일=0)
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  if (days === 0) return "만료까지 D-0";
  return `만료까지 D-${days}`;
}

// ── delta "0" 감지 ─────────────────────────────────────────────────────────
// "▲ 0.0", "▼ 0.0", "+0", "−0" 등 변화 없음 의미의 delta 텍스트 필터

function isDeltaZero(deltaText: string | null | undefined): boolean {
  if (!deltaText) return false;
  return /^[▼▲↘↗+\-−]\s*0(\.0+)?$/.test(deltaText.trim());
}

// ── 날짜 포맷 ──────────────────────────────────────────────────────────────

function formatDate(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  const Y = d.getUTCFullYear();
  const M = String(d.getUTCMonth() + 1).padStart(2, "0");
  const D = String(d.getUTCDate()).padStart(2, "0");
  return `${Y}.${M}.${D}`;
}

// ── 숫자 포맷 ──────────────────────────────────────────────────────────────

function fmt1(n: number): string {
  return n.toFixed(1);
}

function fmtVsPar(v: number | null | undefined): string {
  if (v === null || v === undefined) return "—";
  if (v === 0) return "E";
  if (v > 0) return `+${v}`;
  return `${v}`;
}

// ── 도넛 SVG ──────────────────────────────────────────────────────────────
// 반지름 34, 원주 213.6

interface DonutSegment {
  pct: number;
  color: string;
}

function buildDonutPath(segments: DonutSegment[]): string {
  const r = 34;
  const cx = 45;
  const cy = 45;
  const circumference = 2 * Math.PI * r;

  let offset = 0;
  return segments
    .map((seg) => {
      const dash = (seg.pct / 100) * circumference;
      const gap = circumference - dash;
      const path = `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${escapeHtml(seg.color)}" stroke-width="10" stroke-dasharray="${dash.toFixed(1)} ${gap.toFixed(1)}" stroke-dashoffset="-${offset.toFixed(1)}" />`;
      offset += dash;
      return path;
    })
    .join("");
}

function renderDonutSvg(payload: StatsSharePayload): string {
  const dist = payload.scoreDistribution;
  const total = dist.totalHoles || 1;

  const segments: DonutSegment[] = [
    { pct: (dist.eagleOrBetter / total) * 100, color: "#9b2335" },
    { pct: (dist.birdie / total) * 100, color: "#c0573a" },
    { pct: (dist.par / total) * 100, color: "#1c6b43" },
    { pct: (dist.bogey / total) * 100, color: "#d6a93b" },
    { pct: (dist.doubleOrWorse / total) * 100, color: "#1e40af" },
  ].filter((s) => s.pct > 0);

  const parPct = Math.round((dist.par / total) * 100);
  const paths = buildDonutPath(segments);

  return `<svg viewBox="0 0 90 90" width="90" height="90" style="transform:rotate(-90deg)">
  <circle cx="45" cy="45" r="34" fill="none" stroke="#e6ece7" stroke-width="10"/>
  ${paths}
</svg>
<div class="v-donut-c">
  <div class="n">${parPct}%</div>
  <div class="s">파율</div>
</div>`;
}

// ── Sparkline SVG ─────────────────────────────────────────────────────────
// viewBox="0 0 100 40" + preserveAspectRatio="none" + width="100%" 으로
// 컨테이너 전체 너비를 채우며, points 좌표 X 범위를 0~100 으로 정규화.

function renderSparkline(scores: number[]): string {
  if (scores.length < 2) return "";
  const vbW = 100;
  const vbH = 40;
  const padding = 2; // 상하 클리핑 방지용 패딩
  const min = Math.min(...scores);
  const max = Math.max(...scores);
  const range = max - min || 1;

  const pts = scores.map((s, i) => {
    const x = (i / (scores.length - 1)) * vbW;
    const y = padding + ((max - s) / range) * (vbH - padding * 2);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });

  return `<svg viewBox="0 0 ${vbW} ${vbH}" width="100%" height="40" preserveAspectRatio="none" style="display:block">
  <polyline points="${pts.join(" ")}" fill="none" stroke="#21895a" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
</svg>`;
}

// ── 한국 지도 SVG fallback (noscript 전용) ───────────────────────────────
// 한국 위경도 범위: lat 33~38.6, lng 124.6~130
// SVG 좌표계: 200x260
// JS 활성화 환경에서는 Leaflet 컨테이너가 표시되고, 이 SVG는 noscript 안에 들어감

function latLngToSvg(lat: number, lng: number): { x: number; y: number } {
  const LAT_MIN = 33.0;
  const LAT_MAX = 38.6;
  const LNG_MIN = 124.6;
  const LNG_MAX = 130.0;
  const SVG_W = 200;
  const SVG_H = 260;

  const x = ((lng - LNG_MIN) / (LNG_MAX - LNG_MIN)) * SVG_W;
  const y = SVG_H - ((lat - LAT_MIN) / (LAT_MAX - LAT_MIN)) * SVG_H;
  return { x: Math.max(10, Math.min(SVG_W - 10, x)), y: Math.max(10, Math.min(SVG_H - 10, y)) };
}

function renderKoreaMapSvgFallback(regions: StatsRegionShare[]): string {
  const pins = regions
    .map((r) => {
      const { x, y } = latLngToSvg(r.centroidLat, r.centroidLng);
      return `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="7" fill="#c0573a" stroke="white" stroke-width="2" opacity="0.85"/>
<text x="${x.toFixed(1)}" y="${(y + 1).toFixed(1)}" text-anchor="middle" dominant-baseline="middle" font-size="7" fill="white" font-weight="700">${r.roundCount}</text>`;
    })
    .join("\n");

  return `<svg viewBox="0 0 200 260" width="100%" style="display:block;max-height:160px">
  <!-- 한국 윤곽 (단순 사각형 배경) -->
  <rect x="8" y="8" width="184" height="244" rx="8" fill="#e0eee5" stroke="#c8dfd0" stroke-width="1"/>
  <!-- 서해 -->
  <text x="30" y="140" font-size="8" fill="#94a39b" opacity="0.7">서해</text>
  <!-- 동해 -->
  <text x="165" y="100" font-size="8" fill="#94a39b" opacity="0.7">동해</text>
  <!-- 핀 -->
  ${pins}
</svg>`;
}

// ── Leaflet 인터랙티브 지도 컨테이너 렌더 ────────────────────────────────
// Leaflet CDN 의존. 카톡 인앱 JS 차단 시 noscript fallback (SVG).
// 페이지 스크롤과 충돌 방지 위해 scrollWheelZoom: false. dragging/tap 만 허용.
// roundLocations 있으면 골프장별 정확한 좌표 사용 (terracotta 핀 + 골프장명 tooltip)
// 없으면 region centroid 폴백

function renderLeafletMap(
  regions: StatsRegionShare[],
  roundLocations?: StatsRoundLocationShare[] | null
): string {
  // roundLocations 우선, 없으면 region centroid 폴백
  const useExactLocations = roundLocations != null && roundLocations.length > 0;

  const markersJson = useExactLocations
    ? JSON.stringify(
        roundLocations!.map((loc) => ({
          lat: loc.lat,
          lng: loc.lng,
          name: loc.courseName,
          count: loc.roundCount,
          exact: true,
        }))
      )
    : JSON.stringify(
        regions.map((r) => ({
          lat: r.centroidLat,
          lng: r.centroidLng,
          name: r.displayName,
          count: r.roundCount,
          exact: false,
        }))
      );

  // noscript fallback: roundLocations 있으면 골프장 좌표, 없으면 centroid
  const fallbackRegions: StatsRegionShare[] = useExactLocations
    ? roundLocations!.map((loc) => ({
        displayName: loc.courseName,
        roundCount: loc.roundCount,
        centroidLat: loc.lat,
        centroidLng: loc.lng,
      }))
    : regions;

  const svgFallback = renderKoreaMapSvgFallback(fallbackRegions);

  return `<div class="v-map-leaflet" id="statsMap"></div>
<noscript>
  ${svgFallback}
</noscript>
<script>
window.__STATS_REGIONS__ = ${markersJson};
</script>`;
}

// ── Par별 평균 바 ─────────────────────────────────────────────────────────

function renderParAverages(parAverages: StatsParAverage[]): string {
  // 최대 평균으로 바 너비 정규화
  const maxAvg = Math.max(...parAverages.map((p) => p.averageScore), 1);

  return parAverages
    .map((p) => {
      const barPct = Math.round((p.averageScore / maxAvg) * 100);
      const vsLabel = p.vsPar >= 0 ? `+${fmt1(p.vsPar)}` : fmt1(p.vsPar);
      return `<div class="v-par-row">
  <div class="v-par-tag">P${p.par}</div>
  <div class="v-bar-wrap"><div class="v-bar" style="width:${barPct}%"></div></div>
  <div class="v-par-val">${fmt1(p.averageScore)}<span class="vs">${vsLabel}</span></div>
</div>`;
    })
    .join("\n");
}

// ── 최근 라운드 행 ────────────────────────────────────────────────────────

function vsParPillClass(vsPar: number | null | undefined): string {
  if (vsPar === null || vsPar === undefined) return "";
  if (vsPar <= -1) return "birdie";
  if (vsPar === 0) return "par-pill";
  if (vsPar <= 3) return "bogey";
  return "double";
}

function renderRecentRounds(rounds: StatsRecentEntryShare[]): string {
  return rounds
    .map((r) => {
      const vsStr = fmtVsPar(r.vsPar);
      const pillClass = vsParPillClass(r.vsPar);
      const pillHtml = r.vsPar !== null && r.vsPar !== undefined
        ? `<span class="pill ${pillClass}">${vsStr}</span>`
        : "";
      return `<div class="v-recent-row">
  <div class="left">
    <div class="n">${escapeHtml(r.courseName)}</div>
    <div class="d">${escapeHtml(formatDate(r.dateISO))} · ${r.holeCount}홀</div>
  </div>
  ${pillHtml}
  <div class="s">${r.totalScore}</div>
</div>`;
    })
    .join("\n");
}

// ── 시그니처 카드 hero (C안 — 스코어카드 모티프) ──────────────────────────
// cardKind에 따라 accent 색 다름. 배경 흰색(#fbfdfb), 그라디언트 X.

function sigCardAccent(cardKind: string): { text: string; badge: string; border: string } {
  if (cardKind === "pr")  return { text: "#c0573a", badge: "rgba(192,87,58,0.12)", border: "rgba(192,87,58,0.30)" };
  if (cardKind === "hcp") return { text: "#1c6b43", badge: "rgba(28,107,67,0.12)",  border: "rgba(28,107,67,0.30)" };
  return                          { text: "#21895a", badge: "rgba(33,137,90,0.12)",  border: "rgba(33,137,90,0.30)" };
}

function defaultTagText(cardKind: string): string {
  if (cardKind === "pr")  return "NEW PR";
  if (cardKind === "hcp") return "HDCP DOWN";
  return "IMPROVING";
}

function renderMiniStats(
  stats: StatsSignatureMiniStat[] | null | undefined,
  bigNumber?: string
): string {
  if (!stats || stats.length === 0) return "";

  // value가 빈 문자열 / "0.0" / bigNumber와 동일한 셀은 제외
  const filtered = stats.filter((s) => {
    if (!s.value || s.value.trim() === "") return false;
    if (s.value === "0.0") return false;
    if (bigNumber && s.value === bigNumber) return false;
    return true;
  }).slice(0, 3);

  if (filtered.length === 0) return "";

  const cells = filtered.map((s, i) => {
    const border = i > 0 ? "border-left:1px solid #e6ece7;" : "";
    return `<div style="flex:1;text-align:center;padding:10px 8px;${border}">
  <div style="font-size:15px;font-weight:800;color:#1a2620;font-feature-settings:'tnum';">${escapeHtml(s.value)}</div>
  <div style="font-size:9px;color:#5d6b63;margin-top:2px;">${escapeHtml(s.label)}</div>
</div>`;
  }).join("\n");

  return `<div style="display:flex;border-top:1px solid #e6ece7;border-bottom:1px solid #e6ece7;margin:0 -24px;">
  ${cells}
</div>`;
}

function renderSignatureCard(payload: StatsSharePayload): string {
  const { signature, cardKind, displayName } = payload;
  const accent = sigCardAccent(cardKind);

  const tagText = signature.tagText ?? defaultTagText(cardKind);
  const scoreLabel = (signature.scoreBlockLabel ?? "Score").toUpperCase();
  const subLabel = signature.metaSecondary ?? "";
  const playerName = signature.playerName ?? displayName ?? "";
  const playerMeta = signature.metaPrimary ?? "";

  // delta "0" 의미면 미표시
  const effectiveDelta = isDeltaZero(signature.deltaText) ? null : signature.deltaText;
  const deltaHtml = effectiveDelta
    ? `<span style="font-size:11px;font-weight:800;padding:3px 9px;border-radius:6px;background:${accent.badge};color:${accent.text};margin-left:6px;">${escapeHtml(effectiveDelta)}</span>`
    : "";

  const miniHtml = renderMiniStats(signature.miniStats, signature.bigNumber);

  return `<div class="sig-c-card">
  <!-- 1. 헤더 -->
  <div style="display:flex;align-items:center;justify-content:space-between;padding:14px 18px 0;">
    <span style="color:#1c6b43;font-size:13px;font-weight:900;">라운드온</span>
    <span style="font-size:9px;font-weight:800;letter-spacing:0.05em;padding:3px 8px;border-radius:4px;color:${accent.text};background:${accent.badge};border:1px solid ${accent.border};">${escapeHtml(tagText)}</span>
  </div>
  <!-- 2. 골퍼 행 -->
  <div style="display:flex;align-items:center;justify-content:space-between;padding:8px 18px;border-top:1px solid #e6ece7;border-bottom:2px solid #1a2620;margin-top:8px;">
    <span style="font-size:12px;font-weight:800;color:#1a2620;">${escapeHtml(playerName ? playerName + "님" : "골퍼")}</span>
    <span style="font-size:9px;color:#5d6b63;font-weight:600;">${escapeHtml(playerMeta)}</span>
  </div>
  <!-- 3. 점수 블록 -->
  <div style="padding:8px 18px 0;">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">
      <span style="font-size:9px;font-weight:700;color:#5d6b63;text-transform:uppercase;letter-spacing:0.05em;">${escapeHtml(scoreLabel)}</span>
      <span style="font-size:9px;color:#5d6b63;font-weight:600;">${escapeHtml(subLabel)}</span>
    </div>
    <div style="border-top:1px solid #e6ece7;padding:10px 0 12px;display:flex;align-items:baseline;justify-content:center;gap:6px;flex-wrap:wrap;">
      <span style="font-size:52px;font-weight:900;line-height:1;font-feature-settings:'tnum';letter-spacing:-0.02em;color:${accent.text};">${escapeHtml(signature.bigNumber)}</span>
      ${signature.bigUnit ? `<span style="font-size:13px;color:#5d6b63;font-weight:700;">${escapeHtml(signature.bigUnit)}</span>` : ""}
      ${deltaHtml}
    </div>
    <div style="border-top:1px solid #e6ece7;"></div>
  </div>
  <!-- 4. 미니 통계 -->
  <div style="padding:0 18px;">
    ${miniHtml}
  </div>
  <!-- 5. 푸터 -->
  <div style="display:flex;align-items:center;justify-content:space-between;padding:6px 18px 10px;margin-top:auto;">
    <span style="font-size:8px;color:#94a39b;font-weight:600;">${escapeHtml(signature.footerLabel)}</span>
    <div style="width:18px;height:18px;background:linear-gradient(45deg,#1a2620 25%,transparent 25%) 0 0/3px 3px,linear-gradient(-45deg,#1a2620 25%,transparent 25%) 0 0/3px 3px;border-radius:2px;opacity:0.45;"></div>
  </div>
</div>`;
}

// ── PIN 잠금 화면 ─────────────────────────────────────────────────────────

export function renderStatsPinLock(shortId: string, _meta: StatsShareMeta): string {
  return `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0,viewport-fit=cover"/>
<meta name="theme-color" content="#1c6b43"/>
<title>통계 공유 · 잠금</title>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { background:#f4f7f4; font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo",sans-serif; color:#1a2620; -webkit-font-smoothing:antialiased; }
body { display:flex; align-items:center; justify-content:center; min-height:100vh; padding:24px; }
.box { background:#fff; border-radius:20px; padding:36px 28px; max-width:340px; width:100%; text-align:center; box-shadow:0 4px 24px rgba(28,107,67,0.10); }
.ic { font-size:40px; margin-bottom:12px; }
h1 { font-size:18px; font-weight:700; margin-bottom:6px; }
p { font-size:13px; color:#5d6b63; margin-bottom:20px; }
input { width:100%; padding:12px 14px; border:1.5px solid #e6ece7; border-radius:12px; font-size:24px; text-align:center; letter-spacing:0.3em; outline:none; font-family:monospace; }
input:focus { border-color:#1c6b43; }
button { margin-top:14px; width:100%; padding:13px; background:#1c6b43; color:white; border:none; border-radius:12px; font-size:15px; font-weight:700; cursor:pointer; }
button:active { background:#14492f; }
.err { margin-top:10px; font-size:12px; color:#c0573a; min-height:16px; }
.brand { margin-top:20px; font-size:12px; color:#94a39b; }
</style>
</head>
<body>
<div class="box">
  <div class="ic">&#128274;</div>
  <h1>PIN이 필요합니다</h1>
  <p>이 통계 공유는 PIN으로 보호되어 있습니다.</p>
  <input id="pin" type="password" inputmode="numeric" maxlength="4" pattern="[0-9]*" placeholder="• • • •" autocomplete="off"/>
  <button onclick="submit()">확인</button>
  <div id="err" class="err"></div>
  <div class="brand">라운드온 · Round-On</div>
</div>
<script>
function submit(){
  var pin=document.getElementById('pin').value;
  if(!/^[0-9]{4}$/.test(pin)){document.getElementById('err').textContent='4자리 숫자를 입력해 주세요.';return;}
  fetch('/s/${escapeHtml(shortId)}/verify-pin',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pin:pin})})
  .then(function(r){return r.json().then(function(d){return{ok:r.ok,d:d};});})
  .then(function(res){
    if(res.ok){location.reload();}
    else if(res.d.locked){document.getElementById('err').textContent='PIN 5회 오답으로 잠겼습니다. 1시간 후 재시도하세요.';}
    else{document.getElementById('err').textContent='PIN이 올바르지 않습니다. ('+res.d.attempts+'/5)';}
  })
  .catch(function(){document.getElementById('err').textContent='오류가 발생했습니다. 다시 시도해 주세요.';});
}
document.getElementById('pin').addEventListener('keydown',function(e){if(e.key==='Enter')submit();});
</script>
</body>
</html>`;
}

// ── 메인 viewer 렌더 ──────────────────────────────────────────────────────

export interface StatsViewerOptions {
  shortId: string;
  meta: StatsShareMeta;
  domain: string;
}

export function renderStatsViewer(opts: StatsViewerOptions): string {
  const { meta, domain } = opts;
  const { payload, expiresAt } = meta;

  const dday = calcDday(expiresAt);
  const displayName = escapeHtml(payload.displayName || "사용자");
  const periodLabel = escapeHtml(payload.periodLabel || "");

  // og:image 제거 (v1 — 정적 PNG 자산 미배포)
  // v2 todo: og:image 자산 추가 (satori 또는 정적 PNG: og-stats-{cardKind}.png)
  const ogTitle = `${escapeHtml(payload.signature.headline)} | 라운드온`;
  const ogDesc = `${displayName}님의 골프 통계 · ${periodLabel}`;
  const ogUrl = `https://${escapeHtml(domain)}/s/${escapeHtml(opts.shortId)}`;

  const signatureHtml = renderSignatureCard(payload);

  // 요약 3카드
  const totalRoundsHtml = String(payload.summary.totalRounds);
  const recentAvgHtml = payload.summary.recentAverageScore != null
    ? fmt1(payload.summary.recentAverageScore)
    : "—";
  const avgVsParHtml = payload.summary.averageVsPar != null
    ? (payload.summary.averageVsPar >= 0 ? `+${fmt1(payload.summary.averageVsPar)}` : fmt1(payload.summary.averageVsPar))
    : "—";

  // 스코어 분포
  const dist = payload.scoreDistribution;
  const totalHoles = dist.totalHoles || 1;
  const distLegend = [
    { label: "이글 이상", count: dist.eagleOrBetter, color: "#9b2335" },
    { label: "버디", count: dist.birdie, color: "#c0573a" },
    { label: "파", count: dist.par, color: "#1c6b43" },
    { label: "보기", count: dist.bogey, color: "#d6a93b" },
    { label: "더블+", count: dist.doubleOrWorse, color: "#1e40af" },
  ]
    .map(
      (item) =>
        `<div class="v-legend-row"><div class="l"><span class="swatch" style="background:${item.color}"></span>${item.label}</div><div class="p">${Math.round((item.count / totalHoles) * 100)}%</div></div>`
    )
    .join("\n");

  // Par별 평균
  const parAvgHtml = payload.parAverages.length > 0
    ? renderParAverages(payload.parAverages)
    : "<div style='font-size:12px;color:#94a39b;'>데이터 없음</div>";

  // 흐름 (trend)
  const trendHtml = payload.trend
    ? `<div class="v-trend-row">
  <div class="lbl">최근 흐름</div>
  <div><span class="v">${escapeHtml(payload.trend.directionLabel)}</span><span class="compare">${fmt1(payload.trend.previousAverage)} → ${fmt1(payload.trend.currentAverage)}</span></div>
</div>
<div style="margin-top:8px;">${renderSparkline(payload.trend.scoreTrend)}</div>
${payload.trend.sigmaText ? `<div style="font-size:10px;color:#94a39b;margin-top:4px;">${escapeHtml(payload.trend.sigmaText)}</div>` : ""}`
    : "";

  // 베스트 라운드
  const bestHtml = payload.bestRound
    ? `<div class="v-section">
  <div class="v-section-label">베스트 라운드</div>
  <div class="v-best-card">
    <div>
      <div class="name">${escapeHtml(payload.bestRound.courseName)}</div>
      <div class="date">${escapeHtml(formatDate(payload.bestRound.dateISO))}</div>
      ${payload.bestRound.isPersonalRecord ? `<span class="pr-pill">PR</span>` : ""}
    </div>
    <div style="text-align:right">
      <div class="score">${payload.bestRound.totalScore}</div>
      <div class="score-u">타</div>
    </div>
  </div>
</div>`
    : "";

  // 지역별
  const topRegions = [...payload.regions]
    .sort((a, b) => b.roundCount - a.roundCount)
    .slice(0, 5);

  const regionListHtml = topRegions
    .map(
      (r) =>
        `<div class="v-region-row"><span class="ic"><svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="7" cy="7" r="7" fill="#21895a"/><circle cx="7" cy="7" r="4" fill="white"/><circle cx="7" cy="7" r="2" fill="#21895a"/></svg></span><span class="name">${escapeHtml(r.displayName)}</span><span class="cnt">${r.roundCount}라운드</span></div>`
    )
    .join("\n");

  const mapHtml = renderLeafletMap(topRegions, payload.roundLocations);

  // 최근 5라운드
  const recentHtml = renderRecentRounds(payload.recentRounds.slice(0, 5));

  // 만료일 표기
  const expiresDate = formatDate(new Date(expiresAt).toISOString());

  return `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0,viewport-fit=cover"/>
<meta name="theme-color" content="#1c6b43"/>
<title>${ogTitle}</title>
<meta name="robots" content="noindex,nofollow"/>
<meta property="og:title" content="${ogTitle}"/>
<meta property="og:description" content="${ogDesc}"/>
<meta property="og:url" content="${ogUrl}"/>
<meta property="og:type" content="website"/>
<meta name="twitter:card" content="summary"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
      integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
        integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""
        defer></script>
<style>
  :root {
    --bg: #f4f7f4;
    --card: #ffffff;
    --border: #e6ece7;
    --house: #1c6b43;
    --accent: #21895a;
    --table-head: #f1f9f4;
    --birdie: #c0573a;
    --par: #1c6b43;
    --bogey: #d6a93b;
    --double: #1e40af;
    --ink: #1a2620;
    --ink-soft: #5d6b63;
    --ink-faint: #94a39b;
    --radius-md: 12px;
    --radius-lg: 16px;
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body {
    background:var(--bg);
    font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Segoe UI",system-ui,sans-serif;
    color:var(--ink);
    -webkit-font-smoothing:antialiased;
  }
  body {
    padding: max(20px, env(safe-area-inset-top)) 16px max(40px, env(safe-area-inset-bottom));
  }
  .shell { max-width:480px; margin:0 auto; display:flex; flex-direction:column; gap:14px; }

  /* 헤더 */
  .v-header { display:flex; align-items:center; justify-content:space-between; }
  .v-brand { color:var(--house); font-size:18px; font-weight:800; }
  .v-dday { font-size:11px; color:var(--ink-faint); background:rgba(28,107,67,0.07); padding:4px 10px; border-radius:999px; font-weight:600; }

  /* 작성자 */
  .v-author { display:flex; align-items:center; gap:10px; }
  .v-author .av { width:36px;height:36px;border-radius:18px;background:var(--house);color:white;font-weight:800;display:flex;align-items:center;justify-content:center;font-size:14px;flex-shrink:0; }
  .v-author .name { font-size:15px;font-weight:700;color:var(--ink); }
  .v-author .sub { font-size:11px;color:var(--ink-soft); }

  /* 시그니처 카드 hero — C안 스코어카드 모티프 */
  /* aspect-ratio:1/1 제거 — viewer는 정보 카드 역할이므로 내용 높이에 맞춤 (2026-05-27) */
  .v-sig-wrap { border-radius:var(--radius-lg); overflow:hidden; background:#fbfdfb; border:1px solid var(--border); display:flex; flex-direction:column; box-shadow:0 4px 18px rgba(28,107,67,0.08); }
  .sig-c-card { flex:1; display:flex; flex-direction:column; background:#fbfdfb; }

  /* 섹션 */
  .v-section {}
  .v-section-label { font-size:10px;color:var(--ink-soft);font-weight:700;text-transform:uppercase;letter-spacing:0.06em;margin-bottom:6px;padding:0 2px; }

  /* 요약 3카드 */
  .v-mini-grid { display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px; }
  .v-mini-card { background:var(--card);border:1px solid var(--border);border-radius:var(--radius-md);padding:12px 8px;text-align:center; }
  .v-mini-card .icon { color:var(--accent);font-size:16px;margin-bottom:4px; }
  .v-mini-card .val { font-size:18px;font-weight:800;color:var(--ink);font-feature-settings:"tnum"; }
  .v-mini-card .unit { font-size:9px;color:var(--ink-soft);font-weight:500;margin-left:1px; }
  .v-mini-card .label { margin-top:4px;font-size:10px;color:var(--ink-soft); }

  /* 스코어 분포 */
  .v-dist-card { background:var(--card);border:1px solid var(--border);border-radius:var(--radius-md);padding:14px; }
  .v-dist-body { display:flex;gap:16px;align-items:center; }
  .v-donut { flex-shrink:0;width:90px;height:90px;position:relative; }
  .v-donut svg { transform:rotate(-90deg); }
  .v-donut-c { position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center; }
  .v-donut-c .n { font-size:18px;font-weight:800;color:var(--ink);line-height:1; }
  .v-donut-c .s { font-size:8px;color:var(--ink-soft); }
  .v-legend { flex:1;display:flex;flex-direction:column;gap:5px;font-size:11px; }
  .v-legend-row { display:flex;align-items:center;justify-content:space-between; }
  .v-legend-row .l { display:flex;align-items:center;gap:6px;color:var(--ink);font-weight:500; }
  .swatch { width:9px;height:9px;border-radius:2px;flex-shrink:0; }
  .v-legend-row .p { color:var(--ink-soft);font-weight:700;font-feature-settings:"tnum"; }
  .v-dist-tag { margin-top:10px;padding:8px 10px;background:rgba(33,137,90,0.06);border-left:3px solid var(--accent);border-radius:4px;font-size:11px;color:var(--ink);line-height:1.5; }

  /* Par 별 평균 */
  .v-par-card { background:var(--card);border:1px solid var(--border);border-radius:var(--radius-md);padding:14px; }
  .v-par-row { display:grid;grid-template-columns:28px 1fr 42px;align-items:center;gap:8px;font-size:11px;margin-bottom:8px; }
  .v-par-row:last-of-type { margin-bottom:0; }
  .v-par-tag { background:var(--table-head);color:var(--house);font-weight:700;border-radius:4px;padding:3px 0;text-align:center;font-size:9px; }
  .v-bar-wrap { height:6px;background:var(--bg);border-radius:999px;overflow:hidden; }
  .v-bar { height:100%;background:linear-gradient(90deg,var(--accent),var(--house));border-radius:999px; }
  .v-par-val { text-align:right;font-weight:700;color:var(--ink);font-feature-settings:"tnum"; }
  .v-par-val .vs { display:block;font-size:9px;color:var(--bogey);font-weight:600;line-height:1; }

  /* 흐름 */
  .v-trend-row { margin-top:12px;padding-top:12px;border-top:1px dashed var(--border);display:flex;align-items:center;justify-content:space-between; }
  .v-trend-row .lbl { font-size:10px;color:var(--ink-soft);text-transform:uppercase;letter-spacing:0.06em;font-weight:700; }
  .v-trend-row .v { font-size:13px;font-weight:700;color:var(--accent); }
  .v-trend-row .compare { font-size:11px;color:var(--ink-soft);margin-left:6px;font-feature-settings:"tnum"; }

  /* 베스트 라운드 */
  .v-best-card { background:var(--card);border:1px solid var(--border);border-radius:var(--radius-md);padding:14px 16px;display:flex;align-items:center;justify-content:space-between; }
  .v-best-card .name { font-size:13px;font-weight:700;color:var(--ink); }
  .v-best-card .date { font-size:10px;color:var(--ink-soft);margin-top:2px; }
  .v-best-card .pr-pill { display:inline-block;font-size:9px;color:var(--birdie);background:rgba(192,87,58,0.10);padding:2px 7px;border-radius:999px;margin-top:4px;font-weight:700; }
  .v-best-card .score { font-size:28px;font-weight:800;color:var(--accent);font-feature-settings:"tnum";line-height:1; }
  .v-best-card .score-u { font-size:9px;color:var(--ink-soft);text-align:right; }

  /* 지도 — Leaflet 인터랙티브 */
  .v-map-leaflet {
    height: 220px;
    border-radius: 8px;
    overflow: hidden;
    position: relative;
    background: #e6ece7; /* 로딩 중 placeholder */
    margin-bottom: 6px;
  }
  .v-map-leaflet .leaflet-container {
    height: 100%;
    width: 100%;
    border-radius: 8px;
    background: #e6ece7;
    font-family: inherit;
  }
  .v-map-pin { background: none; border: none; }
  /* 핀 네임태그 — permanent:true 항상 표시 */
  .v-pin-label.leaflet-tooltip {
    background: rgba(255,255,255,0.95);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 10px;
    font-weight: 600;
    color: var(--ink);
    box-shadow: 0 1px 2px rgba(0,0,0,0.08);
    white-space: nowrap;
  }
  .v-pin-label.leaflet-tooltip::before { display: none; } /* 화살표 제거 */

  /* 지도 카드 */
  .v-map-card { background:var(--card);border:1px solid var(--border);border-radius:var(--radius-md);padding:10px; }
  .v-region-row { display:flex;align-items:center;padding:7px 4px;border-bottom:0.5px solid var(--border);font-size:12px; }
  .v-region-row:last-child { border-bottom:none; }
  .v-region-row .ic { color:var(--accent);font-size:13px;margin-right:8px; }
  .v-region-row .name { flex:1;color:var(--ink);font-weight:600; }
  .v-region-row .cnt { color:var(--ink);font-weight:700;font-feature-settings:"tnum"; }

  /* 최근 라운드 */
  .v-recent-card { background:var(--card);border:1px solid var(--border);border-radius:var(--radius-md);overflow:hidden; }
  .v-recent-row { display:flex;align-items:center;padding:10px 14px;border-top:0.5px solid var(--border);font-size:12px; }
  .v-recent-row:first-child { border-top:none; }
  .v-recent-row .left { flex:1; }
  .v-recent-row .left .n { color:var(--ink);font-weight:600; }
  .v-recent-row .left .d { font-size:10px;color:var(--ink-soft);margin-top:1px; }
  .v-recent-row .pill { font-size:9px;padding:2px 6px;border-radius:3px;font-weight:700;margin-right:8px; }
  .v-recent-row .pill.bogey { color:var(--bogey);background:rgba(214,169,59,0.10); }
  .v-recent-row .pill.birdie { color:var(--birdie);background:rgba(192,87,58,0.10); }
  .v-recent-row .pill.double { color:var(--double);background:rgba(30,64,175,0.08); }
  .v-recent-row .pill.par-pill { color:var(--par);background:rgba(28,107,67,0.08); }
  .v-recent-row .s { font-size:14px;font-weight:700;color:var(--ink);font-feature-settings:"tnum"; }

  /* CTA */
  .viewer-cta { background:linear-gradient(135deg,var(--house),var(--accent));color:white;border-radius:var(--radius-lg);padding:18px 16px;text-align:center;box-shadow:0 6px 18px rgba(28,107,67,0.20); }
  .viewer-cta .ttl { font-size:15px;font-weight:800;margin-bottom:4px; }
  .viewer-cta .sub { font-size:12px;opacity:0.85;margin-bottom:12px; }
  .viewer-cta .btn { display:inline-block;background:white;color:var(--house);font-size:13px;font-weight:800;padding:9px 24px;border-radius:999px;box-shadow:0 2px 6px rgba(0,0,0,0.12); }

  /* 푸터 */
  footer { text-align:center;font-size:11px;color:var(--ink-faint);line-height:1.8;padding-bottom:8px; }
  footer a { color:var(--ink-faint); }
</style>
</head>
<body>
<div class="shell">

  <!-- 헤더 -->
  <div class="v-header">
    <span class="v-brand">라운드온</span>
    <span class="v-dday">${escapeHtml(dday)}</span>
  </div>

  <!-- 작성자 -->
  <div class="v-author">
    <div class="av">${escapeHtml((payload.displayName || "?").charAt(0).toUpperCase())}</div>
    <div>
      <div class="name">${displayName}님의 통계</div>
      <div class="sub">${periodLabel}</div>
    </div>
  </div>

  <!-- 시그니처 카드 hero -->
  <div class="v-sig-wrap">
    ${signatureHtml}
  </div>

  <!-- 요약 3카드 -->
  <div class="v-section">
    <div class="v-section-label">요약</div>
    <div class="v-mini-grid">
      <div class="v-mini-card">
        <div class="icon">&#9971;</div>
        <div class="val">${escapeHtml(totalRoundsHtml)}<span class="unit">R</span></div>
        <div class="label">총 라운드</div>
      </div>
      <div class="v-mini-card">
        <div class="icon">&#127920;</div>
        <div class="val">${escapeHtml(recentAvgHtml)}<span class="unit">타</span></div>
        <div class="label">최근 5R 평균</div>
      </div>
      <div class="v-mini-card">
        <div class="icon">&#128200;</div>
        <div class="val">${escapeHtml(avgVsParHtml)}</div>
        <div class="label">Even 대비</div>
      </div>
    </div>
  </div>

  <!-- 스코어 분포 -->
  <div class="v-section">
    <div class="v-section-label">스코어 분포</div>
    <div class="v-dist-card">
      <div class="v-dist-body">
        <div class="v-donut">
          ${renderDonutSvg(payload)}
        </div>
        <div class="v-legend">
          ${distLegend}
        </div>
      </div>
      <div class="v-dist-tag">${escapeHtml(dist.comment)}</div>
    </div>
  </div>

  <!-- Par별 평균 + 흐름 -->
  <div class="v-section">
    <div class="v-section-label">Par별 평균 · 최근 흐름</div>
    <div class="v-par-card">
      ${parAvgHtml}
      ${trendHtml}
    </div>
  </div>

  <!-- 베스트 라운드 -->
  ${bestHtml}

  <!-- 지역별 라운드 -->
  ${topRegions.length > 0 ? `<div class="v-section">
    <div class="v-section-label">지역별 라운드</div>
    <div class="v-map-card">
      ${mapHtml}
      ${regionListHtml}
    </div>
  </div>` : ""}

  <!-- 최근 5라운드 -->
  ${payload.recentRounds.length > 0 ? `<div class="v-section">
    <div class="v-section-label">최근 라운드</div>
    <div class="v-recent-card">
      ${recentHtml}
    </div>
  </div>` : ""}

  <!-- CTA -->
  <div class="viewer-cta">
    <div class="ttl">나도 골프 기록 시작하기</div>
    <div class="sub">라운드온으로 스코어를 기록하고 통계를 확인해 보세요</div>
    <span class="btn">앱 다운로드</span>
  </div>

  <!-- 푸터 -->
  <footer>
    <div>이 페이지는 ${escapeHtml(expiresDate)}에 자동 삭제돼요</div>
    <div>&#169; OpenStreetMap contributors, ODbL 1.0</div>
    <div>라운드온 · Round-On</div>
  </footer>

</div>

<script>
// Leaflet 인터랙티브 지도 초기화
// Leaflet CDN <script defer> 가 늦게 실행되므로 DOMContentLoaded + L 로딩 대기.
// 카톡 인앱 JS 차단 시 noscript fallback (SVG) 표시.
// scrollWheelZoom: false — 페이지 스크롤과 충돌 방지. dragging/tap 만 허용.
function initStatsMap() {
  var el = document.getElementById("statsMap");
  if (!el) return;
  var regions = window.__STATS_REGIONS__;
  if (!regions || regions.length === 0) return;

  // 한국 전체 fallback 중심
  var defaultCenter = [36.5, 127.8];
  var map = L.map("statsMap", {
    zoomControl: true,         // 우상단 +/- 버튼 노출
    scrollWheelZoom: false,    // 페이지 스크롤 보호 — 지도 위 호버 시에만 활성
    doubleClickZoom: true,     // 더블탭/더블클릭 줌 (기본)
    touchZoom: true,           // 모바일 핀치 줌 (기본)
    dragging: true,
    tap: true,
    attributionControl: true
  }).setView(defaultCenter, 7);

  // 데스크탑: 지도 위 호버 시에만 스크롤 줌 활성 (페이지 스크롤 보호)
  el.addEventListener("mouseenter", function() { map.scrollWheelZoom.enable(); });
  el.addEventListener("mouseleave", function() { map.scrollWheelZoom.disable(); });

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 11,
    minZoom: 6,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
  }).addTo(map);

  // 핀 렌더 — exact=true(골프장 정확 좌표): terracotta 배경 + 흰색 깃발 SVG (flag.fill 유사)
  //           exact=false(시도 centroid 폴백): 하우스그린 원 + 횟수 라벨
  // 네임태그: permanent:true 로 항상 표시 (hover 불필요)
  var markers = [];
  var maxCount = 1;
  regions.forEach(function(r) { if (r.count > maxCount) maxCount = r.count; });

  regions.forEach(function(r) {
    var isExact = r.exact === true;
    var radius = isExact ? 14 : (10 + Math.round(10 * (r.count / maxCount))); // 골프장: 14pt 고정, 시도: 10~20pt 비례
    var bgColor = isExact ? "#c0573a" : "#21895a"; // 골프장: terracotta, 시도: 하우스그린
    // flag.fill 유사 SVG (흰색 깃발 모양)
    var flagSvg = '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="1" width="1.5" height="10" rx="0.75" fill="white"/><path d="M3.5 1.5 L10 4 L3.5 6.5 Z" fill="white"/></svg>';
    var labelHtml = isExact
      ? flagSvg // 골프장: 깃발 SVG (exact)
      : String(r.count); // 시도 횟수 라벨 (centroid)
    var icon = L.divIcon({
      className: "v-map-pin",
      html: '<div style="width:' + (radius * 2) + 'px;height:' + (radius * 2) + 'px;background:' + bgColor + ';border:2px solid white;border-radius:50%;box-shadow:0 1px 4px rgba(0,0,0,0.22);display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:11px;font-family:inherit;">' + labelHtml + '</div>',
      iconSize: [radius * 2, radius * 2],
      iconAnchor: [radius, radius]
    });
    var tooltipText = isExact
      ? r.name + (r.count > 1 ? " · " + r.count + "회" : "")
      : r.name + " · " + r.count + "회";
    var m = L.marker([r.lat, r.lng], { icon: icon }).addTo(map);
    // permanent:true — 항상 네임태그 표시 (hover/tap 불필요)
    m.bindTooltip(tooltipText, {
      permanent: true,
      direction: "top",
      offset: [0, -(radius + 2)],
      className: "v-pin-label"
    });
    markers.push(m);
  });

  if (markers.length > 0) {
    var group = L.featureGroup(markers);
    var bounds = group.getBounds().pad(0.3); // 30% 패딩
    map.fitBounds(bounds, { maxZoom: 9 });
  }

  // 컨테이너 사이즈 재계산 (defer 로드 + DOM 레이아웃 타이밍 보정)
  setTimeout(function() { map.invalidateSize(); }, 50);
}

// Leaflet 가 로드되는 시점에 맞춰 init.
// 1) DOMContentLoaded + L 정의: 즉시 init
// 2) DOMContentLoaded 시점에 L 미정의: 폴링 (최대 5초)
function waitForLeafletAndInit() {
  if (typeof L !== "undefined") {
    initStatsMap();
    return;
  }
  var tries = 0;
  var poll = setInterval(function() {
    tries++;
    if (typeof L !== "undefined") {
      clearInterval(poll);
      initStatsMap();
    } else if (tries > 50) {  // 5초 (100ms × 50)
      clearInterval(poll);
    }
  }, 100);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", waitForLeafletAndInit);
} else {
  waitForLeafletAndInit();
}
</script>
</body>
</html>`;
}

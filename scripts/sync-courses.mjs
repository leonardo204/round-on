/**
 * scripts/sync-courses.mjs
 *
 * GitHub Action에서 실행 (Node 20 내장 fetch, crypto)
 * 역할: 골프존 lobby API 전체 수집 → 우리 DB fuzzy 매칭 → Worker /v1/courses/refresh-payload POST
 *
 * 환경 변수:
 *   WORKER_ENDPOINT       e.g. "https://golf.zerolive.co.kr"
 *   REFRESH_HMAC_SECRET   wrangler secret에 등록된 값과 동일
 *   DRY_RUN               "true"이면 Worker 호출 없이 결과만 로그 출력
 *
 * Cloudflare Workers Free Plan 50 subrequest 제한 우회:
 *   GitHub Action runner는 subrequest 제한 없음.
 *   350+ hole-info 호출도 문제없이 처리.
 */

import { readFileSync } from "node:fs";
import { createHmac, randomBytes } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── 설정 ────────────────────────────────────────────────────────────────────

const WORKER_ENDPOINT = process.env.WORKER_ENDPOINT ?? "https://golf.zerolive.co.kr";
const REFRESH_HMAC_SECRET = process.env.REFRESH_HMAC_SECRET ?? "";
const DRY_RUN = process.env.DRY_RUN === "true";

const GZ_BASE = "https://lobby.golfzon.com/v1/courses";
const GZ_HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
  "Referer": "https://www.golfzon.com/",
  "Accept": "application/json",
};

const DICE_THRESHOLD = 0.6;
const HOLE_INFO_BATCH = 5;        // 병렬 hole-info 호출 수
const PAGE_DELAY_MS = 120;        // 페이지네이션 딜레이
const BATCH_DELAY_MS = 150;       // hole-info 배치 딜레이

// DB 경로: repo 루트 기준 (Shared/Resources/courses.json — DB v3 965곳)
const DB_PATH = resolve(__dirname, "../Shared/Resources/courses.json");

// ─── 유틸 ────────────────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function fetchJson(url, retries = 2) {
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, { headers: GZ_HEADERS });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      if (i === retries) throw e;
      await sleep(500);
    }
  }
}

// ─── Dice similarity (2-gram) ─────────────────────────────────────────────────

function diceSimilarity(a, b) {
  if (a === b) return 1;
  if (a.length < 2 || b.length < 2) return 0;
  const bigrams = (s) => {
    const set = new Set();
    for (let i = 0; i < s.length - 1; i++) set.add(s.slice(i, i + 2));
    return set;
  };
  const sa = bigrams(a);
  const sb = bigrams(b);
  let inter = 0;
  for (const g of sa) if (sb.has(g)) inter++;
  return (2 * inter) / (sa.size + sb.size);
}

function normalizeName(name) {
  return name
    .toLowerCase()
    .replace(/\s+/g, "")
    .replace(/[()（）\[\]【】]/g, "")
    .replace(/(컨트리클럽|골프클럽|골프장|골프&리조트|골프|cc|gc|g\.c\.?|c\.c\.?)/g, "")
    .replace(/[^가-힣a-z0-9]/g, "");
}

// ─── ccName 파싱 ─────────────────────────────────────────────────────────────

function parseCcName(ccName) {
  // "포라이즌 - 가든/스카이" → { base: "포라이즌", pairLeft: "가든", pairRight: "스카이" }
  const dashMatch = ccName.match(/^(.+?)\s*[-–—]\s*(.+)$/);
  if (dashMatch) {
    const base = dashMatch[1].trim();
    const subPart = dashMatch[2].trim();
    const slashIdx = subPart.indexOf("/");
    if (slashIdx !== -1) {
      return {
        base,
        pairLeft: subPart.slice(0, slashIdx).trim(),
        pairRight: subPart.slice(slashIdx + 1).trim(),
      };
    }
    return { base, pairLeft: subPart, pairRight: "후반" };
  }
  return { base: ccName.trim(), pairLeft: "전반", pairRight: "후반" };
}

// ─── 골프존 API ───────────────────────────────────────────────────────────────

async function fetchAllGolfzonCourses() {
  const all = [];
  for (let page = 1; page <= 100; page++) {
    try {
      const url = `${GZ_BASE}/course/search/list?page=${page}&softwareType=0&orderType=1`;
      const json = await fetchJson(url);
      if (!Array.isArray(json) || json.length === 0) break;
      const korean = json.filter((c) => c.country === 1);
      all.push(...korean);
      if (page % 5 === 0) console.log(`  page ${page}: 한국 누적 ${all.length}곳`);
      await sleep(PAGE_DELAY_MS);
    } catch (e) {
      console.warn(`  page ${page} 에러: ${e.message} — 중단`);
      break;
    }
  }
  console.log(`[fetch] 총 한국 코스 ${all.length}건`);
  return all;
}

async function fetchHoleInfo(ciCode) {
  try {
    const url = `${GZ_BASE}/course/${ciCode}/details/hole-info`;
    const json = await fetchJson(url);
    if (!json?.holeInfoList || !Array.isArray(json.holeInfoList)) return null;
    const result = json.holeInfoList
      .filter((g) => Array.isArray(g) && g.length > 0)
      .map((g) => g.slice().sort((a, b) => a.holeNo - b.holeNo).map((h) => h.basicPar));
    return result.length > 0 ? result : null;
  } catch (e) {
    console.warn(`  hole-info ciCode=${ciCode} 실패: ${e.message}`);
    return null;
  }
}

// ─── baseName 그룹핑 → unique 9홀 분해 ───────────────────────────────────────

function buildUniqueSubCourses(courseWithHoles) {
  // baseName → Map<subName, { pars, ciCode }>
  const byBase = new Map();

  for (const { gz, groups } of courseWithHoles) {
    const { base, pairLeft, pairRight } = parseCcName(gz.ccName);
    if (!byBase.has(base)) byBase.set(base, new Map());
    const subMap = byBase.get(base);

    const pairs = [
      { name: pairLeft, idx: 0 },
      { name: pairRight, idx: 1 },
    ];
    for (const { name, idx } of pairs) {
      if (!subMap.has(name) && groups[idx] && groups[idx].length > 0) {
        subMap.set(name, { pars: groups[idx], ciCode: gz.ciCode });
      }
    }
  }

  // { baseName, subs: [{ subCourseName, pars }] }[]
  const result = [];
  for (const [base, subMap] of byBase) {
    const subs = [...subMap.entries()].map(([name, { pars, ciCode }]) => ({
      subCourseName: name,
      pars,
      ciCode,
    }));
    result.push({ baseName: base, subs });
  }
  return result;
}

// ─── DB fuzzy 매칭 ────────────────────────────────────────────────────────────

function matchToDb(uniqueGroups, dbCourses) {
  const matched = [];
  let unmatchedCount = 0;

  for (const { baseName, subs } of uniqueGroups) {
    const normGz = normalizeName(baseName);
    let bestScore = 0;
    let bestDb = null;

    for (const db of dbCourses) {
      const score = diceSimilarity(normGz, normalizeName(db.name));
      if (score > bestScore) { bestScore = score; bestDb = db; }
    }

    if (bestScore < DICE_THRESHOLD || !bestDb) {
      console.warn(`  fuzzy 미매칭 (${bestScore.toFixed(2)}) "${baseName}" → 제외`);
      unmatchedCount++;
      continue;
    }

    matched.push({
      courseId: bestDb.id,
      courseName: bestDb.name,
      source: "golfzon-lobby-api",
      confidence: bestScore >= 0.9 ? "high-exact" : "high-fuzzy",
      subCourses: subs.map(({ subCourseName, pars }) => ({ name: subCourseName, pars })),
    });
  }

  console.log(`[match] 매칭 ${matched.length}곳 / 미매칭 ${unmatchedCount}곳`);
  return { matched, unmatchedCount };
}

// ─── HMAC 서명 ────────────────────────────────────────────────────────────────

function signHmac(secret, message) {
  return createHmac("sha256", secret).update(message).digest("hex");
}

// ─── Worker POST ──────────────────────────────────────────────────────────────

async function postToWorker(courses, summary) {
  if (!REFRESH_HMAC_SECRET) {
    throw new Error("REFRESH_HMAC_SECRET 환경 변수가 설정되지 않았습니다.");
  }

  const timestamp = new Date().toISOString();
  const nonce = randomBytes(16).toString("hex");
  const message = `${timestamp}:${nonce}`;
  const sig = signHmac(REFRESH_HMAC_SECRET, message);

  const payload = { timestamp, nonce, courses, summary };

  const res = await fetch(`${WORKER_ENDPOINT}/v1/courses/refresh-payload`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Signature": `hmac-sha256=${sig}`,
    },
    body: JSON.stringify(payload),
  });

  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Worker 응답 오류 ${res.status}: ${text}`);
  }
  console.log(`[worker] 응답 ${res.status}: ${text}`);
  return JSON.parse(text);
}

// ─── 메인 ────────────────────────────────────────────────────────────────────

async function main() {
  console.log("=== 라운드온 코스 동기화 시작 ===");
  if (DRY_RUN) console.log("[dry-run] Worker 호출 없음");

  // 1. 우리 DB 로드
  let dbCourses;
  try {
    const raw = readFileSync(DB_PATH, "utf-8");
    const db = JSON.parse(raw);
    dbCourses = db.courses ?? [];
    console.log(`[db] courses.json 로드: ${dbCourses.length}곳`);
  } catch (e) {
    console.error(`[db] courses.json 로드 실패: ${e.message}`);
    process.exit(1);
  }

  // 2. 골프존 전체 한국 코스 목록
  console.log("\n[1/4] 골프존 코스 목록 페이지네이션...");
  const golfzonCourses = await fetchAllGolfzonCourses();
  if (golfzonCourses.length === 0) {
    console.error("[fetch] 한국 코스 0건 — 중단");
    process.exit(1);
  }

  // 3. hole-info 일괄 fetch (배치 병렬)
  console.log(`\n[2/4] hole-info ${golfzonCourses.length}건 fetch (배치 ${HOLE_INFO_BATCH})...`);
  const courseWithHoles = [];
  for (let i = 0; i < golfzonCourses.length; i += HOLE_INFO_BATCH) {
    const batch = golfzonCourses.slice(i, i + HOLE_INFO_BATCH);
    const results = await Promise.all(
      batch.map(async (gz) => {
        const groups = await fetchHoleInfo(gz.ciCode);
        return groups ? { gz, groups } : null;
      })
    );
    for (const r of results) if (r) courseWithHoles.push(r);

    if (i % 50 === 0 && i > 0) {
      console.log(`  진행 ${i}/${golfzonCourses.length}, hole-info 성공 ${courseWithHoles.length}건`);
    }
    if (i + HOLE_INFO_BATCH < golfzonCourses.length) await sleep(BATCH_DELAY_MS);
  }
  console.log(`[fetch] hole-info 성공 ${courseWithHoles.length}/${golfzonCourses.length}건`);

  // 4. baseName 그룹핑 + unique 9홀 분해
  console.log("\n[3/4] 서브코스 정규화 (X/Y 페어 → unique 9홀)...");
  const uniqueGroups = buildUniqueSubCourses(courseWithHoles);
  console.log(`[normalize] 골프장 ${uniqueGroups.length}곳, 총 서브코스 ${uniqueGroups.reduce((s, g) => s + g.subs.length, 0)}개`);

  // 5. DB fuzzy 매칭
  console.log("\n[4/4] 우리 DB fuzzy 매칭 (Dice >= 0.6)...");
  const { matched, unmatchedCount } = matchToDb(uniqueGroups, dbCourses);

  const summary = {
    totalGolfzonCourses: golfzonCourses.length,
    matched: matched.length,
    unmatched: unmatchedCount,
  };

  console.log(`\n=== 수집 결과 ===`);
  console.log(`  골프존 한국 총: ${summary.totalGolfzonCourses}곳`);
  console.log(`  매칭 성공:      ${summary.matched}곳`);
  console.log(`  매칭 실패:      ${summary.unmatched}곳`);

  if (DRY_RUN) {
    console.log("\n[dry-run] Worker 호출 생략. 완료.");
    return;
  }

  // 6. Worker에 payload 전달
  console.log(`\n[post] POST ${WORKER_ENDPOINT}/v1/courses/refresh-payload ...`);
  try {
    const result = await postToWorker(matched, summary);
    console.log(`[post] 성공:`, result);
  } catch (e) {
    console.error(`[post] 실패: ${e.message}`);
    process.exit(1);
  }

  console.log("\n=== 코스 동기화 완료 ===");
}

main().catch((e) => {
  console.error("[fatal]", e);
  process.exit(1);
});

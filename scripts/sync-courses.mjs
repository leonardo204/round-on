/**
 * scripts/sync-courses.mjs
 *
 * GitHub Action에서 실행 (Node 20 내장 fetch, crypto)
 * 역할:
 *   1. 골프존 lobby API 전체 수집 → unique 골프장 분해
 *   2. MANUAL_ALIASES + fuzzy 매칭 → 우리 DB 연결
 *   3. 미매칭 골프장 → 카카오 Local API 검색 → DB 신규 추가
 *   4. 매칭 골프장 dataQuality "verified" 승격
 *   5. courses.json DB 갱신 (DRY_RUN 미설정 시)
 *   6. Worker /v1/courses/refresh-payload POST
 *
 * 환경 변수:
 *   WORKER_ENDPOINT       e.g. "https://golf.zerolive.co.kr"
 *   REFRESH_HMAC_SECRET   wrangler secret에 등록된 값과 동일
 *   KAKAO_REST_API_KEY    카카오 REST API 키
 *   DRY_RUN               "true"이면 Worker 호출/DB 쓰기 없이 결과만 로그 출력
 *
 * Cloudflare Workers Free Plan 50 subrequest 제한 우회:
 *   GitHub Action runner는 subrequest 제한 없음.
 *   350+ hole-info 호출도 문제없이 처리.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { createHmac, randomBytes } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── 설정 ────────────────────────────────────────────────────────────────────

const WORKER_ENDPOINT = process.env.WORKER_ENDPOINT ?? "https://golf.zerolive.co.kr";
const REFRESH_HMAC_SECRET = process.env.REFRESH_HMAC_SECRET ?? "";
const KAKAO_REST_API_KEY = process.env.KAKAO_REST_API_KEY ?? "";
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

// ─── 수동 alias 매핑 (fuzzy 미달 보강) ───────────────────────────────────────
// 키: 골프존 baseName (정규화 전 원본 일부 포함)
// 값: 우리 DB의 name 필드값
const MANUAL_ALIASES = {
  "이글몬트": "이글골프장",
  "오투 골프&리조트": "오투리조트 골프",
  "노벨": "고성노벨컨트리클럽",
  "타니": "서경타니CC",
  "JNJ": "JNJ골프리조트",
  "포웰CC 안성": "안성컨트리클럽",
  // 2026-05-19: 사용자 수동 검증 — 청우 GC는 알프스대영CC의 별칭
  "청우": "알프스대영컨트리클럽",
};

// ─── 주소 → region 매핑 ────────────────────────────────────────────────────
const ADDRESS_REGION_MAP = [
  { prefix: "서울", region: "서울" },
  { prefix: "부산", region: "부산" },
  { prefix: "대구", region: "대구" },
  { prefix: "인천", region: "인천" },
  { prefix: "광주", region: "광주" },
  { prefix: "대전", region: "대전" },
  { prefix: "울산", region: "울산" },
  { prefix: "세종", region: "세종" },
  { prefix: "경기", region: "경기" },
  { prefix: "강원", region: "강원" },
  { prefix: "충청북도", region: "충북" },
  { prefix: "충청남도", region: "충남" },
  { prefix: "충북", region: "충북" },
  { prefix: "충남", region: "충남" },
  { prefix: "전라북도", region: "전북" },
  { prefix: "전라남도", region: "전남" },
  { prefix: "전북", region: "전북" },
  { prefix: "전남", region: "전남" },
  { prefix: "경상북도", region: "경북" },
  { prefix: "경상남도", region: "경남" },
  { prefix: "경북", region: "경북" },
  { prefix: "경남", region: "경남" },
  { prefix: "제주", region: "제주" },
];

function regionFromAddress(address) {
  if (!address) return "";
  for (const { prefix, region } of ADDRESS_REGION_MAP) {
    if (address.startsWith(prefix)) return region;
  }
  return "";
}

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
    .replace(/(컨트리클럽|골프클럽|골프장|골프&리조트|골프리조트|골프|cc|gc|g\.c\.?|c\.c\.?)/g, "")
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

// ─── DB fuzzy 매칭 (alias 우선) ───────────────────────────────────────────────

function matchToDb(uniqueGroups, dbCourses) {
  const matched = [];
  const unmatched = [];

  // DB 이름 → entry 역인덱스
  const dbByName = new Map(dbCourses.map((c) => [c.name, c]));

  for (const { baseName, subs } of uniqueGroups) {
    // 1) MANUAL_ALIASES 우선 체크
    let dbEntry = null;
    let confidence = "high-exact";

    // alias 키가 baseName에 포함되는지 체크 (부분 매칭도 허용)
    for (const [aliasKey, dbName] of Object.entries(MANUAL_ALIASES)) {
      if (baseName.includes(aliasKey) || baseName === aliasKey) {
        dbEntry = dbByName.get(dbName) ?? null;
        if (dbEntry) {
          console.log(`  [alias] "${baseName}" → "${dbName}" (${dbEntry.id})`);
          confidence = "high-alias";
          break;
        }
      }
    }

    // 2) fuzzy 매칭
    if (!dbEntry) {
      const normGz = normalizeName(baseName);
      let bestScore = 0;
      let bestDb = null;

      for (const db of dbCourses) {
        const score = diceSimilarity(normGz, normalizeName(db.name));
        if (score > bestScore) { bestScore = score; bestDb = db; }
      }

      if (bestScore >= DICE_THRESHOLD && bestDb) {
        dbEntry = bestDb;
        confidence = bestScore >= 0.9 ? "high-exact" : "high-fuzzy";
      }
    }

    if (!dbEntry) {
      console.warn(`  fuzzy 미매칭 "${baseName}" → 미매칭 목록`);
      unmatched.push({ baseName, subs });
      continue;
    }

    matched.push({
      courseId: dbEntry.id,
      courseName: dbEntry.name,
      source: "golfzon-lobby-api",
      confidence,
      subCourses: subs.map(({ subCourseName, pars }) => ({ name: subCourseName, pars })),
      _dbEntry: dbEntry,  // DB 업데이트용 (내부 참조)
    });
  }

  console.log(`[match] 매칭 ${matched.length}곳 / 미매칭 ${unmatched.length}곳`);
  return { matched, unmatched };
}

// ─── 카카오 Local API 검색 ────────────────────────────────────────────────────

async function searchKakao(query) {
  if (!KAKAO_REST_API_KEY) {
    console.warn("  [kakao] KAKAO_REST_API_KEY 미설정 — 스킵");
    return null;
  }
  try {
    const encoded = encodeURIComponent(query);
    const url = `https://dapi.kakao.com/v2/local/search/keyword.json?query=${encoded}&size=5`;
    const res = await fetch(url, {
      headers: { "Authorization": `KakaoAK ${KAKAO_REST_API_KEY}` },
    });
    if (!res.ok) {
      console.warn(`  [kakao] HTTP ${res.status} for "${query}"`);
      return null;
    }
    const json = await res.json();
    const docs = json.documents ?? [];
    if (docs.length === 0) return null;

    // "골프" 포함 우선, 없으면 첫 번째
    const golfDoc = docs.find((d) =>
      (d.place_name ?? "").includes("골프") ||
      (d.category_name ?? "").includes("골프") ||
      (d.category_name ?? "").includes("스포츠")
    ) ?? docs[0];

    return golfDoc;
  } catch (e) {
    console.warn(`  [kakao] 검색 실패 "${query}": ${e.message}`);
    return null;
  }
}

// ─── 신규 DB 항목 생성 ────────────────────────────────────────────────────────

function makeNewDbEntry(baseName, subs, kakaoDoc, existingIds) {
  const address = kakaoDoc?.road_address_name || kakaoDoc?.address_name || null;
  const region = regionFromAddress(address);

  // id 생성: normalizeName(baseName)_region
  const normId = normalizeName(baseName).replace(/[^가-힣a-z0-9]/g, "");
  let candidateId = region ? `${normId}_${region}` : normId;

  // 충돌 방지
  if (existingIds.has(candidateId)) {
    candidateId = `${candidateId}_2`;
  }

  const lat = kakaoDoc?.y ? parseFloat(kakaoDoc.y) : null;
  const lng = kakaoDoc?.x ? parseFloat(kakaoDoc.x) : null;

  return {
    id: candidateId,
    name: baseName,
    region,
    address: address || null,
    phone: kakaoDoc?.phone || null,
    clubhouse: (lat && lng) ? { lat, lng } : null,
    holesCount: subs.length > 0 ? subs.length * 9 : 18,
    courseType: null,
    ownerType: null,
    subCourses: subs.map(({ subCourseName }) => ({ name: subCourseName })),
    dataQuality: (lat && lng) ? "verified" : "minimal",
    sources: [
      "golf-db-pack-v3",
      "golfzon-lobby-api",
      ...(kakaoDoc ? ["kakao-local-api"] : []),
    ],
    ...(kakaoDoc?.place_url ? { kakaoPlaceUrl: kakaoDoc.place_url } : {}),
  };
}

// ─── DB 업데이트 (matched: verified 승격, unmatched: 신규 추가) ──────────────

async function enrichAndUpdateDb(dbData, matched, unmatched) {
  const dbCourses = dbData.courses;
  const dbIdSet = new Set(dbCourses.map((c) => c.id));

  let verifiedCount = 0;
  let newCount = 0;
  let kakaoHit = 0;
  let kakaoMiss = 0;

  // 1. matched → verified 승격
  for (const m of matched) {
    const idx = dbCourses.findIndex((c) => c.id === m._dbEntry.id);
    if (idx === -1) continue;
    const entry = dbCourses[idx];
    if (entry.dataQuality !== "verified") {
      entry.dataQuality = "verified";
      verifiedCount++;
    }
    if (!entry.sources.includes("golfzon-lobby-api")) {
      entry.sources.push("golfzon-lobby-api");
    }
    // subCourses 보강: 기존이 비어있으면 골프존 데이터로 채움 (보수적)
    if ((!entry.subCourses || entry.subCourses.length === 0) && m.subCourses.length > 0) {
      entry.subCourses = m.subCourses.map(({ name }) => ({ name }));
    }
  }

  // 2. unmatched → 카카오 검색 → 신규 추가
  const newEntries = [];
  for (const { baseName, subs } of unmatched) {
    console.log(`  [kakao] 검색: "${baseName} 골프장"`);

    // 먼저 "골프장" 붙여 검색, 실패 시 원본으로 재시도
    let kakaoDoc = await searchKakao(`${baseName} 골프장`);
    if (!kakaoDoc) {
      kakaoDoc = await searchKakao(baseName);
    }

    if (kakaoDoc) {
      kakaoHit++;
      console.log(`    hit: "${kakaoDoc.place_name}" (${kakaoDoc.address_name})`);
    } else {
      kakaoMiss++;
      console.warn(`    miss: "${baseName}" — minimal entry 생성`);
    }

    const newEntry = makeNewDbEntry(baseName, subs, kakaoDoc, dbIdSet);
    dbIdSet.add(newEntry.id);
    newEntries.push(newEntry);
    newCount++;

    await sleep(100); // 카카오 rate limit 대응
  }

  // 3. 신규 항목 DB에 append
  dbCourses.push(...newEntries);

  // 4. id 알파벳 정렬
  dbCourses.sort((a, b) => a.id.localeCompare(b.id, "ko"));

  // 5. 메타 업데이트
  dbData.totalCourses = dbCourses.length;
  dbData.generatedAt = new Date().toISOString();

  return { verifiedCount, newCount, kakaoHit, kakaoMiss, newEntries };
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
  if (DRY_RUN) console.log("[dry-run] Worker 호출 및 DB 쓰기 없음");

  // 1. 우리 DB 로드
  let dbData;
  let dbCourses;
  try {
    const raw = readFileSync(DB_PATH, "utf-8");
    dbData = JSON.parse(raw);
    dbCourses = dbData.courses ?? [];
    console.log(`[db] courses.json 로드: ${dbCourses.length}곳`);
  } catch (e) {
    console.error(`[db] courses.json 로드 실패: ${e.message}`);
    process.exit(1);
  }

  // 2. 골프존 전체 한국 코스 목록
  console.log("\n[1/5] 골프존 코스 목록 페이지네이션...");
  const golfzonCourses = await fetchAllGolfzonCourses();
  if (golfzonCourses.length === 0) {
    console.error("[fetch] 한국 코스 0건 — 중단");
    process.exit(1);
  }

  // 3. hole-info 일괄 fetch (배치 병렬)
  console.log(`\n[2/5] hole-info ${golfzonCourses.length}건 fetch (배치 ${HOLE_INFO_BATCH})...`);
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
  console.log("\n[3/5] 서브코스 정규화 (X/Y 페어 → unique 9홀)...");
  const uniqueGroups = buildUniqueSubCourses(courseWithHoles);
  console.log(`[normalize] 골프장 ${uniqueGroups.length}곳, 총 서브코스 ${uniqueGroups.reduce((s, g) => s + g.subs.length, 0)}개`);

  // 5. DB fuzzy 매칭 (MANUAL_ALIASES 우선)
  console.log("\n[4/5] 우리 DB 매칭 (alias 우선 → fuzzy Dice >= 0.6)...");
  const { matched, unmatched } = matchToDb(uniqueGroups, dbCourses);

  // 6. DB 보강 (verified 승격 + 카카오 신규 추가)
  console.log(`\n[5/5] DB 보강 (미매칭 ${unmatched.length}곳 카카오 검색 + verified 승격)...`);
  const { verifiedCount, newCount, kakaoHit, kakaoMiss, newEntries } =
    await enrichAndUpdateDb(dbData, matched, unmatched);

  const summary = {
    totalGolfzonCourses: golfzonCourses.length,
    matched: matched.length,
    unmatched: unmatched.length,
    verifiedUpgraded: verifiedCount,
    newDbEntries: newCount,
    kakaoHit,
    kakaoMiss,
  };

  console.log(`\n=== 동기화 결과 ===`);
  console.log(`  골프존 한국 총:    ${summary.totalGolfzonCourses}건`);
  console.log(`  매칭 성공:         ${summary.matched}곳`);
  console.log(`  미매칭:            ${summary.unmatched}곳`);
  console.log(`  verified 승격:     ${summary.verifiedUpgraded}곳`);
  console.log(`  DB 신규 추가:      ${summary.newDbEntries}곳`);
  console.log(`  카카오 hit:        ${summary.kakaoHit}곳`);
  console.log(`  카카오 miss:       ${summary.kakaoMiss}곳`);
  console.log(`  DB 총 코스:        ${dbData.totalCourses}곳`);

  if (newEntries.length > 0) {
    console.log(`\n  신규 추가 골프장:`);
    for (const e of newEntries) {
      console.log(`    [${e.dataQuality}] ${e.name} (${e.id}) — ${e.address || "주소없음"}`);
    }
  }

  if (DRY_RUN) {
    console.log(`\n[dry-run] DB 쓰기 생략. +${newCount}곳 추가, ${verifiedCount}곳 verified 승격 시뮬레이션.`);
    console.log("[dry-run] Worker 호출 생략. 완료.");
    return;
  }

  // 7. DB JSON 저장
  console.log(`\n[db] courses.json 저장 중... (총 ${dbData.totalCourses}곳)`);
  writeFileSync(DB_PATH, JSON.stringify(dbData, null, 2), "utf-8");
  console.log("[db] 저장 완료.");

  // 8. Worker에 payload 전달
  // matched 외에 신규 추가된 코스의 par 데이터도 포함
  const workerPayload = [
    ...matched.map((m) => ({
      courseId: m.courseId,
      courseName: m.courseName,
      source: m.source,
      confidence: m.confidence,
      subCourses: m.subCourses,
    })),
    ...newEntries.map((e) => ({
      courseId: e.id,
      courseName: e.name,
      source: "golfzon-lobby-api",
      confidence: "new-entry",
      subCourses: (e.subCourses ?? []).map((sc) => ({ name: sc.name, pars: [] })),
    })),
  ];

  console.log(`\n[post] POST ${WORKER_ENDPOINT}/v1/courses/refresh-payload ...`);
  try {
    const result = await postToWorker(workerPayload, summary);
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

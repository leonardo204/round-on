/**
 * 골프존 lobby API fetch + normalize 로직
 *
 * 검증된 스크립트 기반 재구현 (golfzon_batch.js / normalize_subcourses.js)
 * 실제 API:
 *   코스 목록: GET /v1/courses/course/search/list?page=N&softwareType=0&orderType=1
 *             → 직접 JSON 배열 (wrapper 없음), country=1 클라이언트 필터
 *   hole-info: GET /v1/courses/course/{ciCode}/details/hole-info
 *             → { holeInfoList: [[{courseTypeOrder,holeNo,basicPar,...},...],[...]] }
 */

/** 골프존 API 기본 URL */
const GZ_BASE = "https://lobby.golfzon.com/v1/courses";

const GZ_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
  "Referer": "https://www.golfzon.com/",
  "Accept": "application/json",
};

// ─── 타입 정의 ────────────────────────────────────────────────────────────────

/** 골프존 코스 검색 결과 단건 (실제 API 응답 기준) */
interface GzCourse {
  ciCode: number;       // number (예: 100001057)
  ccName: string;       // "포라이즌 - 가든/스카이" 형식
  country: number;      // 1=한국, 2=일본, 4=미국, 6=유럽
  holeCount: number;
  parCount: number;
  address?: string;
  [key: string]: unknown;
}

/** hole-info 단건 */
interface GzHoleInfo {
  courseTypeOrder: number;
  holeNo: number;
  basicPar: number;
  ciCode: number;
  [key: string]: unknown;
}

/** 우리 DB CourseEntry (최소 필드) */
export interface DbCourse {
  id: string;
  name: string;
  nameEn?: string;
}

/** fuzzy 매칭 결과 */
export interface MatchedPars {
  courseId: string;
  courseName: string;
  subCourseName: string;
  pars: number[];
}

/**
 * normalize된 서브코스 (syncCourses.ts 호환 유지)
 * fetchAndNormalizeAll() 반환 타입
 */
export interface NormalizedSubCourse {
  /** baseName (골프장 고유명, ccName 페어 분리 후) */
  baseName: string;
  /** unique 9홀 코스명 (예: "가든", "스카이") */
  subCourseName: string;
  holeCount: number;
  pars: number[];
  /** 매칭 출처 ciCode */
  ciCode: number;
  /** golfzonFetch 내부 식별자 */
  golfzonId: string;
}

// ─── 헬퍼 ────────────────────────────────────────────────────────────────────

/** sleep (Worker 환경에서도 setTimeout 가능) */
function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

/**
 * 코스명 정규화: 공백·괄호·특수문자 제거, 소문자화
 */
export function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+/g, "")
    .replace(/[()（）\[\]【】]/g, "")
    .replace(/[^가-힣a-z0-9]/g, "");
}

/**
 * 두 이름의 fuzzy 유사도 (0~1) — Dice coefficient (2-gram)
 */
function diceSimilarity(a: string, b: string): number {
  if (a === b) return 1;
  if (a.length < 2 || b.length < 2) return 0;

  const bigrams = (s: string): Set<string> => {
    const set = new Set<string>();
    for (let i = 0; i < s.length - 1; i++) set.add(s.slice(i, i + 2));
    return set;
  };

  const sa = bigrams(a);
  const sb = bigrams(b);
  let intersection = 0;
  for (const g of sa) if (sb.has(g)) intersection++;
  return (2 * intersection) / (sa.size + sb.size);
}

/**
 * ccName에서 baseName + 페어 서브코스명 추출
 *
 * 패턴:
 *   "포라이즌 - 가든/스카이"  → base="포라이즌",  pair=["가든","스카이"]
 *   "용원 GC - 무학/백구"    → base="용원 GC",   pair=["무학","백구"]
 *   "파인스톤 CC"            → base="파인스톤 CC", pair=["전반","후반"]
 */
function parseCcName(ccName: string): { base: string; pairLeft: string; pairRight: string } {
  // 구분자: " - " 또는 "–" 또는 "—"
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
    // 슬래시 없는 경우 — 단순 서브코스명
    return { base, pairLeft: subPart, pairRight: "후반" };
  }
  // 대시 없는 경우 — 단일 코스
  return { base: ccName.trim(), pairLeft: "전반", pairRight: "후반" };
}

// ─── 골프존 API 호출 ─────────────────────────────────────────────────────────

/**
 * 골프존 코스 목록 전체 페이지네이션
 * URL: /v1/courses/course/search/list?page=N&softwareType=0&orderType=1
 * 응답: 직접 JSON 배열 (wrapper 없음)
 */
export async function fetchAllGolfzonCourses(): Promise<GzCourse[]> {
  const all: GzCourse[] = [];

  for (let page = 1; page <= 100; page++) {
    const url = `${GZ_BASE}/course/search/list?page=${page}&softwareType=0&orderType=1`;
    let list: GzCourse[];

    try {
      const res = await fetch(url, { headers: GZ_HEADERS });
      if (!res.ok) {
        console.warn(`[golfzon] 코스 목록 HTTP ${res.status} page=${page}`);
        break;
      }
      const json = await res.json();
      if (!Array.isArray(json) || json.length === 0) break;
      list = json as GzCourse[];
    } catch (e) {
      console.warn(`[golfzon] 코스 목록 fetch 오류 page=${page}: ${e}`);
      break;
    }

    // country=1 (한국)만 클라이언트 필터
    const korean = list.filter((c) => c.country === 1);
    all.push(...korean);

    if (page % 5 === 0) {
      console.log(`[golfzon] page ${page}: 한국 누적 ${all.length}곳`);
    }

    // 예의 있는 딜레이 (page 간 120ms)
    await sleep(120);
  }

  console.log(`[golfzon] 총 한국 코스 ${all.length}건`);
  return all;
}

/**
 * 단일 ciCode hole-info 조회
 * URL: /v1/courses/course/{ciCode}/details/hole-info
 * 응답: { holeInfoList: [[{courseTypeOrder,holeNo,basicPar},...],[...]] }
 * 반환: 9홀 par 배열의 배열 (전반/후반 각 9개)
 */
export async function fetchCourseHoleInfo(ciCode: number): Promise<number[][] | null> {
  const url = `${GZ_BASE}/course/${ciCode}/details/hole-info`;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url, { headers: GZ_HEADERS });
      if (!res.ok) {
        if (res.status === 404) return null;
        throw new Error(`HTTP ${res.status}`);
      }
      const json = await res.json() as { holeInfoList?: GzHoleInfo[][] };
      if (!json?.holeInfoList || !Array.isArray(json.holeInfoList)) return null;

      // 각 그룹(9홀)을 holeNo 순 정렬 후 basicPar 추출
      const result = json.holeInfoList
        .filter((group) => Array.isArray(group) && group.length > 0)
        .map((group) =>
          group
            .slice()
            .sort((a, b) => a.holeNo - b.holeNo)
            .map((h) => h.basicPar)
        );

      return result.length > 0 ? result : null;
    } catch (e) {
      if (attempt === 2) {
        console.warn(`[golfzon] hole-info ciCode=${ciCode} 실패: ${e}`);
        return null;
      }
      await sleep(500);
    }
  }
  return null;
}

// ─── baseName 그룹핑 + unique 9홀 분해 ───────────────────────────────────────

/**
 * 같은 baseName의 모든 ciCode 페어 수집:
 *   ciCode → { base, pairLeft, pairRight, holeGroups: number[][] }
 *
 * 결과: baseName → unique 9홀 서브코스 목록 { subCourseName, pars, ciCode }
 */
function buildUniqueSubCourses(
  courseWithHoles: Array<{
    gz: GzCourse;
    groups: number[][];
  }>
): Map<string, Array<{ subCourseName: string; pars: number[]; ciCode: number }>> {
  // baseName → { uniqueSubName → { pars, ciCode } }
  const byBase = new Map<string, Map<string, { pars: number[]; ciCode: number }>>();

  for (const { gz, groups } of courseWithHoles) {
    const { base, pairLeft, pairRight } = parseCcName(gz.ccName);

    if (!byBase.has(base)) byBase.set(base, new Map());
    const subMap = byBase.get(base)!;

    // groups[0] = 전반 9홀 (pairLeft), groups[1] = 후반 9홀 (pairRight)
    const pairs = [
      { name: pairLeft, groupIdx: 0 },
      { name: pairRight, groupIdx: 1 },
    ];

    for (const { name, groupIdx } of pairs) {
      if (!subMap.has(name) && groups[groupIdx] && groups[groupIdx].length > 0) {
        subMap.set(name, { pars: groups[groupIdx], ciCode: gz.ciCode });
      }
    }
  }

  // Map<baseName, Array<...>> 형태로 변환
  const result = new Map<string, Array<{ subCourseName: string; pars: number[]; ciCode: number }>>();
  for (const [base, subMap] of byBase) {
    const subs = [...subMap.entries()].map(([subCourseName, { pars, ciCode }]) => ({
      subCourseName,
      pars,
      ciCode,
    }));
    result.set(base, subs);
  }
  return result;
}

// ─── 전체 플로우 ──────────────────────────────────────────────────────────────

/**
 * 전체 플로우: 골프존 API → NormalizedSubCourse[]
 * 1. 한국 코스 목록 수집
 * 2. 각 ciCode hole-info 조회 (concurrencyLimit 병렬)
 * 3. baseName 그룹핑 → unique 9홀 서브코스 분해
 */
export async function fetchAndNormalizeAll(
  concurrencyLimit = 5
): Promise<NormalizedSubCourse[]> {
  const courses = await fetchAllGolfzonCourses();
  console.log(`[golfzon] 코스 목록 ${courses.length}개 조회 완료`);

  // hole-info 병렬 조회 (concurrencyLimit 단위 배치)
  const courseWithHoles: Array<{ gz: GzCourse; groups: number[][] }> = [];

  for (let i = 0; i < courses.length; i += concurrencyLimit) {
    const batch = courses.slice(i, i + concurrencyLimit);
    const results = await Promise.all(
      batch.map(async (gz) => {
        const groups = await fetchCourseHoleInfo(gz.ciCode);
        return groups ? { gz, groups } : null;
      })
    );
    for (const r of results) {
      if (r) courseWithHoles.push(r);
    }
    // 배치 간 딜레이 (100ms)
    if (i + concurrencyLimit < courses.length) await sleep(100);
  }

  console.log(`[golfzon] hole-info 조회 성공 ${courseWithHoles.length}개 / ${courses.length}개`);

  // baseName 그룹핑 → unique 9홀 분해
  const uniqueMap = buildUniqueSubCourses(courseWithHoles);

  const all: NormalizedSubCourse[] = [];
  for (const [baseName, subs] of uniqueMap) {
    for (const sub of subs) {
      all.push({
        baseName,
        subCourseName: sub.subCourseName,
        holeCount: sub.pars.length,
        pars: sub.pars,
        ciCode: sub.ciCode,
        golfzonId: `${sub.ciCode}_${sub.subCourseName}`,
      });
    }
  }

  console.log(`[golfzon] 정규화된 서브코스 ${all.length}개 (골프장 ${uniqueMap.size}곳)`);
  return all;
}

// ─── DB fuzzy 매칭 ────────────────────────────────────────────────────────────

/**
 * 골프존 unique 서브코스 → 우리 DB fuzzy 매칭
 * baseName ↔ DB course name 비교 (Dice similarity 0.6 threshold)
 */
export function matchToDb(
  subCourses: NormalizedSubCourse[],
  dbCourses: DbCourse[]
): MatchedPars[] {
  const THRESHOLD = 0.6;
  const results: MatchedPars[] = [];

  // baseName 별로 그룹핑해서 DB 매칭 1회씩 수행
  const byBase = new Map<string, NormalizedSubCourse[]>();
  for (const sc of subCourses) {
    if (!byBase.has(sc.baseName)) byBase.set(sc.baseName, []);
    byBase.get(sc.baseName)!.push(sc);
  }

  for (const [baseName, subs] of byBase) {
    const normGz = normalizeName(baseName);

    let bestScore = 0;
    let bestDb: DbCourse | null = null;

    for (const db of dbCourses) {
      const normDb = normalizeName(db.name);
      const score = diceSimilarity(normGz, normDb);
      if (score > bestScore) {
        bestScore = score;
        bestDb = db;
      }
      if (db.nameEn) {
        const normEn = normalizeName(db.nameEn);
        const scoreEn = diceSimilarity(normGz, normEn);
        if (scoreEn > bestScore) {
          bestScore = scoreEn;
          bestDb = db;
        }
      }
    }

    if (bestScore < THRESHOLD || !bestDb) {
      console.warn(
        `[golfzon] fuzzy 매칭 실패 (score=${bestScore.toFixed(2)}) baseName="${baseName}" → 제외`
      );
      continue;
    }

    for (const sub of subs) {
      results.push({
        courseId: bestDb.id,
        courseName: bestDb.name,
        subCourseName: sub.subCourseName,
        pars: sub.pars,
      });
    }
  }

  console.log(`[golfzon] fuzzy 매칭: ${results.length}개 서브코스 / ${byBase.size}개 골프장 처리`);
  return results;
}

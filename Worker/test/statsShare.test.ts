/**
 * 통계 공유 v1 통합 테스트
 * vitest + miniflare v4 (esbuild 번들링)
 *
 * 케이스:
 *  1. POST /api/share/stats → 201, shortId prefix s_, editToken 32자, url 정확
 *  2. POST without PIN → KV 에 pinHash 없음
 *  3. POST with PIN → KV 에 pinHash bcrypt 저장 확인
 *  4. GET /s/:shortId → 200, HTML 응답에 payload 데이터 포함
 *  5. GET /s/invalid → 404
 *  6. GET /s/s_xxxxxxxx 만료 → 410
 *  7. PUT /api/share/stats/:id 정상 editToken → 200
 *  8. PUT /api/share/stats/:id 잘못된 editToken → 401
 *  9. DELETE /api/share/stats/:id → 204, 재GET → 404
 * 10. 라운드 viewer 회귀 smoke — POST /api/share (라운드) 정상 동작
 *
 * og:image v2 (2026-07-17):
 * 11. ogImage 포함 생성 → /og/{shortId}.png 200 + image/png, viewer 에 og:image 메타
 * 12. ogImage 없이 생성 → /og 404 + og:image 메타 없음 (v1 하위 호환)
 * 13. PIN + ogImage → og 미저장 + /og 404 + 메타 미출력 (보안 회귀 방지)
 * 14. 크기 초과 ogImage → 공유는 201 성공, og 미저장
 * 15. PNG 아닌 데이터 / 깨진 base64 → 공유는 201 성공, og 미저장
 * 16. DELETE → og 동반 삭제
 * 17. PUT 으로 PIN 신규 설정 → 기존 og 폐기 (/og 404 + 메타 미출력)
 * 18. /og/{잘못된 형식}.png → 404
 */

import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Miniflare } from "miniflare";
import { build } from "esbuild";
import path from "path";

// ── Worker 번들 (한 번만 빌드) ─────────────────────────────────────────────

let workerScript = "";

beforeAll(async () => {
  const result = await build({
    entryPoints: [path.resolve(__dirname, "../src/index.ts")],
    bundle: true,
    format: "esm",
    target: "es2022",
    platform: "browser",
    write: false,
  });
  workerScript = result.outputFiles[0].text;
}, 30_000);

// ── Miniflare 인스턴스 팩토리 ────────────────────────────────────────────

async function createMf(): Promise<Miniflare> {
  return new Miniflare({
    modules: true,
    script: workerScript,
    kvNamespaces: [
      "KV_META",
      "KV_RATELIMIT",
      "KV_PINLOCK",
      "KV_SESSION",
      "KV_COURSES",
      "KV_STATS",
    ],
    compatibilityDate: "2026-05-11",
    compatibilityFlags: ["nodejs_compat"],
    bindings: {
      ENVIRONMENT: "test",
      VIEWER_DOMAIN: "localhost",
    },
  });
}

// ── 테스트 페이로드 헬퍼 ─────────────────────────────────────────────────

function makePayload(cardKind: "pr" | "hcp" | "trend" = "pr") {
  return {
    cardKind,
    signature: {
      headline: "인생 최저타를 갱신했어요",
      bigNumber: "82",
      bigUnit: "타",
      deltaText: "−4",
      metaPrimary: "레이크사이드 동코스 · Par 72",
      metaSecondary: "이전 PR 86타 (2026.04.12)",
      footerLabel: "골프장 PR · 추정 핸디캡 17.1",
    },
    summary: {
      totalRounds: 24,
      recentAverageScore: 87.4,
      averageVsPar: 15.2,
    },
    scoreDistribution: {
      eagleOrBetter: 1,
      birdie: 18,
      par: 130,
      bogey: 172,
      doubleOrWorse: 111,
      totalHoles: 432,
      comment: "보기 골퍼 — 더블+ 25.7%",
    },
    parAverages: [
      { par: 3, averageScore: 3.8, vsPar: 0.8, holeCount: 144 },
      { par: 4, averageScore: 5.0, vsPar: 1.0, holeCount: 216 },
      { par: 5, averageScore: 6.0, vsPar: 1.0, holeCount: 72 },
    ],
    trend: {
      direction: "improving",
      directionLabel: "↘ 좋아지는 중",
      previousAverage: 92.1,
      currentAverage: 87.4,
      delta: -5,
      scoreTrend: [95, 92, 90, 88, 87, 89, 86, 84, 85, 82],
      sigmaText: "평균 ±4타",
    },
    bestRound: {
      courseName: "레이크사이드 동코스",
      dateISO: "2026-05-27",
      totalScore: 82,
      isPersonalRecord: true,
    },
    regions: [
      { displayName: "경기도", roundCount: 12, centroidLat: 37.4, centroidLng: 127.5 },
      { displayName: "제주도", roundCount: 5, centroidLat: 33.4, centroidLng: 126.5 },
    ],
    recentRounds: [
      { courseName: "레이크사이드", dateISO: "2026-05-27", totalScore: 82, vsPar: 10, holeCount: 18 },
      { courseName: "남촌CC", dateISO: "2026-05-20", totalScore: 86, vsPar: 14, holeCount: 18 },
    ],
    displayName: "홍길동",
    createdAtISO: "2026-05-27T12:00:00Z",
    periodLabel: "최근 24R",
  };
}

// ── og:image 테스트 픽스처 ────────────────────────────────────────────────

/** 유효한 1x1 PNG (base64, data URI prefix 없음) — PNG 매직바이트 포함 */
const VALID_PNG_B64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

/** 1.5MB 상한 초과 base64 (크기 검사가 디코드보다 먼저 걸린다) */
const OVERSIZED_B64 = "A".repeat(1_600_000);

/** 디코드는 되지만 PNG 매직바이트가 아닌 데이터 ("hello world") */
const NOT_PNG_B64 = "aGVsbG8gd29ybGQ=";

/** base64 로 디코드조차 안 되는 문자열 */
const BROKEN_B64 = "!!!이건 base64 가 아님!!!";

/**
 * KV 에서 og PNG 키(stats:{shortId}:og) 직접 조회
 *
 * 키 리터럴을 statsOg.ts 에서 import 하지 않고 여기 고정한다 — 구현이 키 규약을 바꾸면
 * 이 테스트가 깨져야 의도치 않은 변경을 잡을 수 있다 (독립 검증).
 */
async function readOgKey(mf: Miniflare, shortId: string): Promise<ArrayBuffer | null> {
  const kv = await mf.getKVNamespace("KV_STATS");
  return (await kv.get(`stats:${shortId}:og`, "arrayBuffer")) as ArrayBuffer | null;
}

/** 통계 공유 생성 헬퍼 */
async function createShare(
  mf: Miniflare,
  body: Record<string, unknown>
): Promise<{ status: number; shortId: string; editToken: string }> {
  const res = await mf.dispatchFetch("http://localhost/api/share/stats", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (res.status !== 201) {
    return { status: res.status, shortId: "", editToken: "" };
  }
  const json = (await res.json()) as { shortId: string; editToken: string };
  return { status: res.status, shortId: json.shortId, editToken: json.editToken };
}

// ── 테스트 케이스 ─────────────────────────────────────────────────────────

describe("통계 공유 v1 통합 테스트", () => {
  // ──── 케이스 1: POST /api/share/stats 기본 생성 ──────────────────────
  it("1. POST /api/share/stats → 201, shortId prefix s_, editToken 32자, url 정확", async () => {
    const mf = await createMf();
    try {
      const res = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("pr"),
          deviceToken: "test-device-001",
        }),
      });

      expect(res.status).toBe(201);
      const json = await res.json() as {
        shortId: string;
        url: string;
        editToken: string;
        expiresAt: string;
      };

      expect(json.shortId).toMatch(/^s_[0-9A-Za-z]{8}$/);
      expect(json.editToken).toHaveLength(32); // 32자 hex
      expect(json.url).toBe(`https://localhost/s/${json.shortId}`);
      expect(json.expiresAt).toBeTruthy();
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 2: POST without PIN → pinHash 없음 ───────────────────────
  it("2. POST without PIN → KV에 pinHash 없음", async () => {
    const mf = await createMf();
    try {
      const res = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("hcp"),
          deviceToken: "test-device-002",
        }),
      });
      expect(res.status).toBe(201);
      const json = await res.json() as { shortId: string };

      const kv = await mf.getKVNamespace("KV_STATS");
      const raw = await kv.get(`stats:${json.shortId}`);
      expect(raw).not.toBeNull();
      const meta = JSON.parse(raw!) as { pinHash?: string };
      expect(meta.pinHash).toBeUndefined();
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 3: POST with PIN → pinHash bcrypt 저장 ──────────────────
  it("3. POST with PIN → KV에 pinHash bcrypt 저장", async () => {
    const mf = await createMf();
    try {
      const res = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("trend"),
          pin: "1234",
          deviceToken: "test-device-003",
        }),
      });
      expect(res.status).toBe(201);
      const json = await res.json() as { shortId: string };

      const kv = await mf.getKVNamespace("KV_STATS");
      const raw = await kv.get(`stats:${json.shortId}`);
      expect(raw).not.toBeNull();
      const meta = JSON.parse(raw!) as { pinHash?: string };
      expect(meta.pinHash).toBeTruthy();
      // bcrypt hash 형식 확인
      expect(meta.pinHash!).toMatch(/^\$2[aby]\$/);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 4: GET /s/:shortId → 200 HTML ───────────────────────────
  it("4. GET /s/:shortId → 200 HTML, payload 데이터 포함", async () => {
    const mf = await createMf();
    try {
      // 먼저 생성
      const createRes = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("pr"),
          deviceToken: "test-device-004",
        }),
      });
      const { shortId } = await createRes.json() as { shortId: string };

      // viewer 조회
      const viewRes = await mf.dispatchFetch(`http://localhost/s/${shortId}`);
      expect(viewRes.status).toBe(200);
      const ct = viewRes.headers.get("Content-Type") ?? "";
      expect(ct).toContain("text/html");
      const html = await viewRes.text();
      // 핵심 데이터 포함 확인
      expect(html).toContain("인생 최저타를 갱신했어요");
      expect(html).toContain("홍길동");
      expect(html).toContain("라운드온");
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 5: GET /s/invalid → 404 ────────────────────────────────
  it("5. GET /s/invalid (패턴 불일치) → 404", async () => {
    const mf = await createMf();
    try {
      // /s/ 경로지만 s_ prefix 없는 shortId
      const res = await mf.dispatchFetch("http://localhost/s/invalid1234");
      expect(res.status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 6: 만료 → 410 ───────────────────────────────────────────
  it("6. GET /s/:shortId 만료 → 410", async () => {
    const mf = await createMf();
    try {
      // 수동으로 만료된 메타 삽입
      const shortId = "s_EXPIRED1";
      const expiredMeta = {
        shortId,
        payload: makePayload("pr"),
        editToken: "a".repeat(32),
        createdAt: Date.now() - 8 * 86400 * 1000, // 8일 전
        expiresAt: Date.now() - 1000,             // 이미 만료
        deviceToken: "test",
      };
      const kv = await mf.getKVNamespace("KV_STATS");
      await kv.put(`stats:${shortId}`, JSON.stringify(expiredMeta));

      const res = await mf.dispatchFetch(`http://localhost/s/${shortId}`);
      expect(res.status).toBe(410);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 7: PUT 정상 editToken → 200 ─────────────────────────────
  it("7. PUT /api/share/stats/:id 정상 editToken → 200", async () => {
    const mf = await createMf();
    try {
      const createRes = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("hcp"),
          deviceToken: "test-device-007",
        }),
      });
      const { shortId, editToken } = await createRes.json() as {
        shortId: string;
        editToken: string;
      };

      const updPayload = makePayload("hcp");
      updPayload.displayName = "수정된이름";

      const putRes = await mf.dispatchFetch(
        `http://localhost/api/share/stats/${shortId}`,
        {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${editToken}`,
          },
          body: JSON.stringify({ payload: { displayName: "수정된이름" } }),
        }
      );
      expect(putRes.status).toBe(200);
      const putJson = await putRes.json() as { shortId: string };
      expect(putJson.shortId).toBe(shortId);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 8: PUT 잘못된 editToken → 401 ───────────────────────────
  it("8. PUT /api/share/stats/:id 잘못된 editToken → 401", async () => {
    const mf = await createMf();
    try {
      const createRes = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("trend"),
          deviceToken: "test-device-008",
        }),
      });
      const { shortId } = await createRes.json() as { shortId: string };

      const putRes = await mf.dispatchFetch(
        `http://localhost/api/share/stats/${shortId}`,
        {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer wrongtoken1234567890123456789012",
          },
          body: JSON.stringify({ payload: { displayName: "해킹시도" } }),
        }
      );
      expect(putRes.status).toBe(401);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 9: DELETE → 204, 재GET → 404 ────────────────────────────
  it("9. DELETE /api/share/stats/:id → 204, 재GET → 404", async () => {
    const mf = await createMf();
    try {
      const createRes = await mf.dispatchFetch("http://localhost/api/share/stats", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          payload: makePayload("pr"),
          deviceToken: "test-device-009",
        }),
      });
      const { shortId, editToken } = await createRes.json() as {
        shortId: string;
        editToken: string;
      };

      // DELETE
      const delRes = await mf.dispatchFetch(
        `http://localhost/api/share/stats/${shortId}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${editToken}` },
        }
      );
      expect(delRes.status).toBe(204);

      // 재조회 → 404
      const getRes = await mf.dispatchFetch(`http://localhost/s/${shortId}`);
      expect(getRes.status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 10: 라운드 viewer 회귀 smoke ─────────────────────────────
  it("10. POST /api/share (라운드) 회귀 smoke — 기존 엔드포인트 정상 동작", async () => {
    const mf = await createMf();
    try {
      const res = await mf.dispatchFetch("http://localhost/api/share", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          deviceToken: "smoke-device-010",
          round: {
            id: "round-test-id",
            courseName: "테스트 골프장",
            date: "2026-05-27",
            players: [{ id: "p1", name: "테스터", totalScore: 90 }],
            holes: [
              { number: 1, par: 4, scores: [{ playerId: "p1", shots: 5 }] },
            ],
          },
          options: {
            nameVisibility: "real",
            accessControl: "public",
          },
        }),
      });

      expect(res.status).toBe(201);
      const json = await res.json() as { shortId: string; url: string };
      // 라운드 viewer shortId는 s_ prefix 없는 8자 base62
      expect(json.shortId).toMatch(/^[0-9A-Za-z]{8}$/);
      expect(json.url).toContain(json.shortId);
    } finally {
      await mf.dispose();
    }
  });
});

// ── og:image v2 (2026-07-17) ──────────────────────────────────────────────

describe("통계 공유 og:image v2", () => {
  // ──── 케이스 11: ogImage 포함 생성 → /og 200 + viewer 메타 ─────────────
  it("11. ogImage 포함 생성 → /og/{shortId}.png 200 + image/png, viewer 에 og:image 메타", async () => {
    const mf = await createMf();
    try {
      const { status, shortId } = await createShare(mf, {
        payload: makePayload("pr"),
        deviceToken: "og-device-011",
        ogImage: VALID_PNG_B64,
      });
      expect(status).toBe(201);

      // KV 에 og 저장 + meta 플래그
      expect(await readOgKey(mf, shortId)).not.toBeNull();
      const kv = await mf.getKVNamespace("KV_STATS");
      const meta = JSON.parse((await kv.get(`stats:${shortId}`))!) as { hasOgImage?: boolean };
      expect(meta.hasOgImage).toBe(true);

      // /og 서빙
      const ogRes = await mf.dispatchFetch(`http://localhost/og/${shortId}.png`);
      expect(ogRes.status).toBe(200);
      expect(ogRes.headers.get("Content-Type")).toBe("image/png");
      expect(ogRes.headers.get("Cache-Control")).toContain("immutable");

      // 실제 PNG 매직바이트가 그대로 서빙되는지
      const bytes = new Uint8Array(await ogRes.arrayBuffer());
      expect(Array.from(bytes.slice(0, 8))).toEqual([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

      // viewer og 메타
      const html = await (await mf.dispatchFetch(`http://localhost/s/${shortId}`)).text();
      expect(html).toContain(`<meta property="og:image" content="https://localhost/og/${shortId}.png"/>`);
      expect(html).toContain('<meta property="og:image:width" content="1080"/>');
      expect(html).toContain('<meta property="og:image:height" content="1080"/>');
      expect(html).toContain('<meta property="og:image:type" content="image/png"/>');
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 12: ogImage 없이 생성 → 하위 호환 ────────────────────────
  it("12. ogImage 없이 생성 (구버전 앱) → /og 404 + og:image 메타 없음", async () => {
    const mf = await createMf();
    try {
      const { status, shortId } = await createShare(mf, {
        payload: makePayload("hcp"),
        deviceToken: "og-device-012",
      });
      expect(status).toBe(201);

      expect(await readOgKey(mf, shortId)).toBeNull();

      const ogRes = await mf.dispatchFetch(`http://localhost/og/${shortId}.png`);
      expect(ogRes.status).toBe(404);

      // viewer 는 정상 렌더되되 og:image 메타만 없음 (og:title 은 유지 — 카톡 폴백)
      const viewRes = await mf.dispatchFetch(`http://localhost/s/${shortId}`);
      expect(viewRes.status).toBe(200);
      const html = await viewRes.text();
      expect(html).not.toContain("og:image");
      expect(html).toContain('property="og:title"');
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 13: PIN + ogImage → og 미저장/미노출 (보안 회귀 방지) ─────
  it("13. PIN 설정된 공유 → og 미저장 + /og 404 + og:image 메타 미출력", async () => {
    const mf = await createMf();
    try {
      const { status, shortId } = await createShare(mf, {
        payload: makePayload("pr"),
        pin: "1234",
        deviceToken: "og-device-013",
        ogImage: VALID_PNG_B64,
      });
      // 공유 자체는 정상 생성
      expect(status).toBe(201);

      // PIN 공유는 og 를 아예 저장하지 않는다 (미리보기로 스코어 유출 차단)
      expect(await readOgKey(mf, shortId)).toBeNull();
      const kv = await mf.getKVNamespace("KV_STATS");
      const meta = JSON.parse((await kv.get(`stats:${shortId}`))!) as {
        hasOgImage?: boolean;
        pinHash?: string;
      };
      expect(meta.pinHash).toBeTruthy();
      expect(meta.hasOgImage).toBeFalsy();

      // og 라우트 404
      const ogRes = await mf.dispatchFetch(`http://localhost/og/${shortId}.png`);
      expect(ogRes.status).toBe(404);

      // 크롤러(쿠키 없음)가 받는 PIN 잠금 화면에 og:image 메타 없음 + 스코어 누출 없음
      const viewRes = await mf.dispatchFetch(`http://localhost/s/${shortId}`);
      expect(viewRes.status).toBe(200);
      const html = await viewRes.text();
      expect(html).not.toContain("og:image");
      expect(html).not.toContain("인생 최저타를 갱신했어요");
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 13-b: PIN 공유가 og 를 서빙하지 않음 (KV 강제 주입 방어) ──
  it("13-b. PIN 메타 + og 키가 강제로 함께 존재해도 /og 404 (서빙 시점 이중 방어)", async () => {
    const mf = await createMf();
    try {
      // v1 메타 또는 미래 경로로 og 가 남아있는 상황을 KV 에 직접 구성
      const shortId = "s_PinLeak1";
      const kv = await mf.getKVNamespace("KV_STATS");
      await kv.put(
        `stats:${shortId}`,
        JSON.stringify({
          shortId,
          payload: makePayload("pr"),
          editToken: "b".repeat(32),
          pinHash: "$2a$10$abcdefghijklmnopqrstuv",
          createdAt: Date.now(),
          expiresAt: Date.now() + 7 * 86400 * 1000,
          hasOgImage: true,
        })
      );
      await kv.put(`stats:${shortId}:og`, Uint8Array.from(atob(VALID_PNG_B64), (c) => c.charCodeAt(0)));

      const ogRes = await mf.dispatchFetch(`http://localhost/og/${shortId}.png`);
      expect(ogRes.status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 14: 크기 초과 → 공유 성공, og 미저장 ─────────────────────
  it("14. 1.5MB 초과 ogImage → 공유는 201 성공, og 미저장 (/og 404)", async () => {
    const mf = await createMf();
    try {
      const { status, shortId } = await createShare(mf, {
        payload: makePayload("trend"),
        deviceToken: "og-device-014",
        ogImage: OVERSIZED_B64,
      });
      // 이미지 때문에 공유가 실패하면 안 된다
      expect(status).toBe(201);
      expect(shortId).toMatch(/^s_[0-9A-Za-z]{8}$/);

      expect(await readOgKey(mf, shortId)).toBeNull();
      const ogRes = await mf.dispatchFetch(`http://localhost/og/${shortId}.png`);
      expect(ogRes.status).toBe(404);

      // viewer 는 og 없이 정상 렌더
      const viewRes = await mf.dispatchFetch(`http://localhost/s/${shortId}`);
      expect(viewRes.status).toBe(200);
      expect(await viewRes.text()).not.toContain("og:image");
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 15: PNG 아님 / 깨진 base64 → 공유 성공, og 미저장 ────────
  it("15. PNG 매직바이트 불일치 → 공유는 201 성공, og 미저장", async () => {
    const mf = await createMf();
    try {
      const { status, shortId } = await createShare(mf, {
        payload: makePayload("pr"),
        deviceToken: "og-device-015a",
        ogImage: NOT_PNG_B64,
      });
      expect(status).toBe(201);
      expect(await readOgKey(mf, shortId)).toBeNull();
      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  it("15-b. base64 디코드 실패 → 공유는 201 성공, og 미저장", async () => {
    const mf = await createMf();
    try {
      const { status, shortId } = await createShare(mf, {
        payload: makePayload("pr"),
        deviceToken: "og-device-015b",
        ogImage: BROKEN_B64,
      });
      expect(status).toBe(201);
      expect(await readOgKey(mf, shortId)).toBeNull();
      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 16: DELETE → og 동반 삭제 ───────────────────────────────
  it("16. DELETE /api/share/stats/:id → og 키도 함께 삭제 + /og 404", async () => {
    const mf = await createMf();
    try {
      const { shortId, editToken } = await createShare(mf, {
        payload: makePayload("pr"),
        deviceToken: "og-device-016",
        ogImage: VALID_PNG_B64,
      });
      expect(await readOgKey(mf, shortId)).not.toBeNull();

      const delRes = await mf.dispatchFetch(`http://localhost/api/share/stats/${shortId}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${editToken}` },
      });
      expect(delRes.status).toBe(204);

      // 공유 삭제 후 og 가 남아 카드 이미지를 계속 서빙하면 안 된다
      expect(await readOgKey(mf, shortId)).toBeNull();
      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 17: PUT 으로 PIN 신규 설정 → og 폐기 ────────────────────
  it("17. PUT 으로 PIN 신규 설정 → 기존 og 폐기 (/og 404 + 메타 미출력)", async () => {
    const mf = await createMf();
    try {
      const { shortId, editToken } = await createShare(mf, {
        payload: makePayload("pr"),
        deviceToken: "og-device-017",
        ogImage: VALID_PNG_B64,
      });
      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(200);

      // PIN 을 나중에 거는 경우 — 미리보기 이미지가 남으면 스코어가 새어나간다
      const putRes = await mf.dispatchFetch(`http://localhost/api/share/stats/${shortId}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${editToken}`,
        },
        body: JSON.stringify({ pin: "9876" }),
      });
      expect(putRes.status).toBe(200);

      expect(await readOgKey(mf, shortId)).toBeNull();
      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(404);

      const html = await (await mf.dispatchFetch(`http://localhost/s/${shortId}`)).text();
      expect(html).not.toContain("og:image");
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 17-b: PUT payload 갱신 → og 유지 ────────────────────────
  it("17-b. PUT payload 갱신(PIN 무관) → 기존 og 유지", async () => {
    const mf = await createMf();
    try {
      const { shortId, editToken } = await createShare(mf, {
        payload: makePayload("pr"),
        deviceToken: "og-device-017b",
        ogImage: VALID_PNG_B64,
      });

      const putRes = await mf.dispatchFetch(`http://localhost/api/share/stats/${shortId}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${editToken}`,
        },
        body: JSON.stringify({ payload: { displayName: "수정된이름" } }),
      });
      expect(putRes.status).toBe(200);

      // og 교체는 미지원이지만 payload 갱신이 기존 og 를 날려서도 안 된다
      expect(await readOgKey(mf, shortId)).not.toBeNull();
      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(200);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 18: 잘못된 shortId 형식 → 404 ───────────────────────────
  it("18. /og/{잘못된 형식}.png → 404", async () => {
    const mf = await createMf();
    try {
      // s_ prefix 없음
      expect((await mf.dispatchFetch("http://localhost/og/abcd1234.png")).status).toBe(404);
      // 길이 불일치
      expect((await mf.dispatchFetch("http://localhost/og/s_abc.png")).status).toBe(404);
      // 존재하지 않는 정상 형식 shortId
      expect((await mf.dispatchFetch("http://localhost/og/s_ZZZZZZZZ.png")).status).toBe(404);
      // 확장자 없음
      expect((await mf.dispatchFetch("http://localhost/og/s_ZZZZZZZZ")).status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });

  // ──── 케이스 19: 만료된 공유의 og → 404 ──────────────────────────────
  it("19. 만료된 공유의 og → 404", async () => {
    const mf = await createMf();
    try {
      const shortId = "s_OgExpir1";
      const kv = await mf.getKVNamespace("KV_STATS");
      await kv.put(
        `stats:${shortId}`,
        JSON.stringify({
          shortId,
          payload: makePayload("pr"),
          editToken: "c".repeat(32),
          createdAt: Date.now() - 8 * 86400 * 1000,
          expiresAt: Date.now() - 1000, // 이미 만료
          hasOgImage: true,
        })
      );
      await kv.put(`stats:${shortId}:og`, Uint8Array.from(atob(VALID_PNG_B64), (c) => c.charCodeAt(0)));

      expect((await mf.dispatchFetch(`http://localhost/og/${shortId}.png`)).status).toBe(404);
    } finally {
      await mf.dispose();
    }
  });
});

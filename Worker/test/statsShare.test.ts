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

# 30 — API 명세 (Cloudflare Worker)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [21-DATA_MODEL](21-DATA_MODEL.md) · [31-VIEWER_HTML](31-VIEWER_HTML.md) · [32-CLOUDFLARE_SETUP](32-CLOUDFLARE_SETUP.md) · [33-SECURITY](33-SECURITY.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §3.3 (01-SPEC.md:259-284), §9 (01-SPEC.md:655-672)
> **관련 문서**: `21-DATA_MODEL.md` (SwiftData 모델), `31-VIEWER_HTML.md`, `32-CLOUDFLARE_SETUP.md`, `33-SECURITY.md`
>
> ⚠️ **2026-05-18 폐기 사항**: 사진 관련 4개 엔드포인트 모두 제거됨 — `POST /api/share/:id/photos`, `DELETE /api/share/:id/photos/:photoId`, `GET /:id/photo/:photoId`, `GET /:id/photos.zip`. R2 binding + 사진 rate limit + ShareMeta.photos 필드 모두 제거. 본 문서의 사진 관련 모든 섹션(§5, §6.3~§6.4, §9.1, §9.5)은 무효이며 별도 patch 없이 폐기됨으로 간주.

> **[spec 미정의 5건 일람]**
>
> 아래 5개 항목은 `01-SPEC.md`에 설계 의도만 있고 구체적 명세가 없다. 본 문서에서 각 항목이 등장하는 곳에 `[SPEC-UNDEFINED]` 라벨을 표기하며, 구현 권장안은 §9에 모아 두었다.
>
> 1. 라운드 전체 DELETE 엔드포인트 (Round 삭제, viewer 회수) — §9.6
> 2. PIN 검증 엔드포인트 (PIN 보호 viewer 진입 시 처리 방식) — §9.2
> 3. round JSON 페이로드 구조 (SwiftData Round → 와이어 직렬화 스키마) — §9.3
> 4. 에러 응답 본문 스키마 — §9.4
> 5. 사진 업로드 형식 (multipart/form-data vs base64) — §9.1
>
> 추가 권장 2건은 spec 미정의가 아닌 보강 제안이다: §9.5(POST /photos Rate limit) / §9.7(Idempotency-Key + OpenAPI 산출물).

---

## 1. 목적 / 범위

본 문서는 라운드온 iPhone 앱과 Cloudflare Worker 간 **HTTP API** 명세를 다룬다.

**다루는 영역**:
- 7개 엔드포인트의 요청/응답 구조
- 인증 토큰 모델 (3토큰 분리)
- 에러 코드 및 HTTP 상태 표
- Rate limiting 및 보안 제약

**다루지 않는 영역** (위임):

| 문서 | 위임 영역 |
|------|----------|
| `21-DATA_MODEL.md` | SwiftData @Model 스키마, Viewer 공유 필드 원본 정의 |
| `31-VIEWER_HTML.md` (작성 예정) | `GET /:shortId` 응답 HTML 구조 및 CSS 디테일 |
| `32-CLOUDFLARE_SETUP.md` (작성 예정) | KV/R2 네임스페이스, wrangler.toml, TTL 설정 |
| `33-SECURITY.md` (작성 예정) | bcrypt cost factor, PII 패턴 매칭 정규식 디테일 |

---

## 2. 공통 사항 및 인증 모델

### 2.1 Base URL 및 공통 헤더

| 항목 | 값 | 출처 |
|------|----|------|
| Base URL | `https://golf.zerolive.co.kr` | 01-SPEC.md:6 |
| 전송 프로토콜 | HTTPS only (Cloudflare 자동 적용) | 01-SPEC.md:281 |
| 기본 Content-Type | `application/json; charset=UTF-8` | (사진 업로드 제외) |
| 사진 업로드 Content-Type | `multipart/form-data` [SPEC-UNDEFINED: 권장] | §9.1 참조 |

### 2.2 3토큰 분리 모델

01-SPEC.md §3.4의 보안 설계는 세 가지 독립 토큰으로 구성된다. (01-SPEC.md:277-278, 670)

| 토큰 | 역할 | 발급 주체 | 전달 방식 | 출처 |
|------|------|----------|---------|------|
| `deviceToken` | 발급자 추적 (익명 UUID). Rate limiting 기준 | 앱 최초 실행 시 생성 — 외부 노출 없는 익명 UUID | 요청 바디 | 01-SPEC.md:670 |
| `editToken` | 수정 권한 인증 (PUT/DELETE 헤더 필수). KV에 저장, 디바이스 외부 노출 금지 | Worker가 POST /api/share 응답 시 생성 | `Authorization` 요청 헤더 | 01-SPEC.md:277 |
| `PIN` | viewer 접근 제어 (4자리 숫자). bcrypt 해시로 KV 저장 | 공유 생성 시 사용자가 선택 입력 | 요청 바디 (`pin` 필드) | 01-SPEC.md:278 |

---

## 3. POST /api/share (viewer 생성)

```
POST /api/share
```

라운드 데이터를 Cloudflare KV/R2에 저장하고 shortId + URL + editToken을 반환한다. (01-SPEC.md:262-264)

### 요청

```json
{
  "deviceToken": "550e8400-e29b-41d4-a716-446655440000",
  "round": { },
  "options": {
    "nameVisibility": "real | anonymous",
    "accessControl": "public | pin",
    "pin": "1234"
  }
}
```

- `deviceToken`: 익명 UUID, Rate limiting 기준 (01-SPEC.md:670)
- `round`: SwiftData Round 객체의 JSON 직렬화 **[SPEC-UNDEFINED: 페이로드 구조 미정의 — §9.3 참조]**
- `options.nameVisibility`: `"real"` 실명 / `"anonymous"` 익명(A/B/C/D) (01-SPEC.md:131)
- `options.accessControl`: `"public"` 공개 / `"pin"` PIN 보호 (01-SPEC.md:132)
- `options.pin`: `accessControl == "pin"` 일 때만 필수 (4자리 숫자). Worker에서 bcrypt 해시 저장 (01-SPEC.md:278)

### 응답 201

```json
{
  "shortId": "aB3dE7fG",
  "url": "https://golf.zerolive.co.kr/aB3dE7fG",
  "editToken": "tok_xxxxxxxxxxxxxxxxxxxxxxxx",
  "expiresAt": "2026-05-18T09:00:00Z"
}
```

21-DATA_MODEL §8 Viewer 공유 필드와의 1:1 매핑:

| 응답 필드 | Round 모델 필드 | 설명 | 출처 |
|----------|---------------|------|------|
| `shortId` | `sharedShortId` | base62 8자 단축 ID | 01-SPEC.md:276, 21-DATA_MODEL §8 |
| `url` | `sharedURL` | 전체 Viewer URL | 01-SPEC.md:125, 21-DATA_MODEL §8 |
| `editToken` | `sharedEditToken` | 수정/삭제용 토큰 (로컬 저장) | 01-SPEC.md:277, 21-DATA_MODEL §8 |
| `expiresAt` | `sharedExpiresAt` | 생성 시점 + 7일 (ISO 8601 UTC) | 01-SPEC.md:126, 21-DATA_MODEL §8 |

에러: 400 / 413 / 429 — §7 참조.

---

## 4. PUT /api/share/{shortId} (viewer 업데이트)

```
PUT /api/share/{shortId}
```

기존 shortId를 유지하면서 메타데이터를 갱신한다. 사진 수정은 §5 엔드포인트를 사용한다. (01-SPEC.md:139-142, 266)

### 헤더

```
Authorization: Bearer {editToken}
```

헤더 형식은 **[SPEC-UNDEFINED]** — 본 문서 예시는 `Authorization: Bearer {editToken}` 표기를 잠정 채택. 최종 형식(`Authorization: Bearer` vs `X-Edit-Token` 등)은 `33-SECURITY.md` (작성 예정)에서 확정.

### 요청

```json
{
  "round": { },
  "options": {
    "nameVisibility": "real | anonymous",
    "accessControl": "public | pin",
    "pin": "5678"
  }
}
```

`round` 및 `options` 는 변경할 항목만 포함 가능 (partial update 권장). (01-SPEC.md:140-141)

### 응답 200

```json
{
  "shortId": "aB3dE7fG",
  "url": "https://golf.zerolive.co.kr/aB3dE7fG",
  "expiresAt": "2026-05-18T09:00:00Z"
}
```

에러: 401 (editToken 불일치) / 404 (shortId 없음) / 410 (만료) — §7 참조.

---

## 5. 사진 엔드포인트

### 5.1 POST /api/share/{shortId}/photos (사진 추가)

```
POST /api/share/{shortId}/photos
```

사진을 R2에 저장하고 photoId를 반환한다. (01-SPEC.md:267)

**헤더**:
```
Authorization: Bearer {editToken}
Content-Type: multipart/form-data
```

업로드 형식은 **[SPEC-UNDEFINED: multipart/form-data 권장 — §9.1 참조]**

**요청 (multipart/form-data)**:

| 필드 | 타입 | 설명 |
|------|------|------|
| `photo` | 파일 (JPEG/PNG) | 업로드할 사진. 최대 10MB (01-SPEC.md:279) |
| `holeNumber` | 숫자 (선택) | 연결할 홀 번호 |
| `caption` | 문자열 (선택) | 사진 캡션 |

**응답 201**:

```json
{
  "photoId": "ph_xxxxxxxxxxxx",
  "remoteURL": "https://golf.zerolive.co.kr/aB3dE7fG/photo/ph_xxxxxxxxxxxx"
}
```

**제약** (01-SPEC.md:279):
- 1장 최대 10MB
- viewer당 최대 30장

에러: 401 / 404 / 413 (용량 초과) / 429 — §7 참조.

### 5.2 DELETE /api/share/{shortId}/photos/{photoId} (사진 삭제)

```
DELETE /api/share/{shortId}/photos/{photoId}
```

R2에서 해당 사진 파일을 삭제하고 KV 메타데이터에서 참조를 제거한다. (01-SPEC.md:268)

**헤더**:
```
Authorization: Bearer {editToken}
```

**응답 204**: 본문 없음.

에러: 401 / 404 — §7 참조.

---

## 6. GET 엔드포인트 (viewer 및 사진)

### 6.1 GET /:shortId (viewer HTML)

```
GET /:shortId
```

스코어카드 + 사진 갤러리를 포함하는 모바일 최적화 HTML을 반환한다. (01-SPEC.md:269)

- 응답 `Content-Type`: `text/html; charset=UTF-8`
- PIN 보호 viewer의 경우 잠금 화면을 먼저 렌더링한다. (01-SPEC.md:239-240)
- HTML 구조 및 CSS 디테일은 `31-VIEWER_HTML.md` (작성 예정)에 위임한다.
- PIN 검증 처리 방식은 **[SPEC-UNDEFINED: 권장안 — §9.2 참조]**

**분기**:

| 조건 | Worker 동작 |
|------|------------|
| `accessControl == "public"` | 스코어카드 + 갤러리 HTML 직접 응답 |
| `accessControl == "pin"` | PIN 입력 잠금 화면 HTML 응답 (200) |
| shortId 없음 | 404 |
| 만료됨 (7일 경과) | 410 (01-SPEC.md:126) |

### 6.2 GET /:shortId/photo/:photoId (사진 인라인)

```
GET /:shortId/photo/:photoId
```

img 태그에서 사용하는 인라인 사진 응답이다. (01-SPEC.md:270)

- 응답 `Content-Type`: `image/jpeg` 또는 `image/png`
- `Content-Disposition`: `inline`
- R2에서 스트리밍 응답

### 6.3 GET /:shortId/photo/:photoId?download=1 (사진 다운로드)

```
GET /:shortId/photo/:photoId?download=1
```

사진을 파일로 다운로드한다. (01-SPEC.md:270)

- `download=1` 쿼리 파라미터 존재 시 `Content-Disposition: attachment; filename="{photoId}.jpg"` 헤더를 추가한다.

### 6.4 GET /:shortId/photos.zip (전체 사진 ZIP)

```
GET /:shortId/photos.zip
```

viewer에 속한 전체 사진을 ZIP으로 압축하여 스트리밍 다운로드한다. (01-SPEC.md:271)

- 응답 `Content-Type`: `application/zip`
- `Content-Disposition: attachment; filename="roundon-{shortId}.zip"`
- R2에서 파일을 순차적으로 읽어 스트리밍 ZIP 생성 (Cloudflare Workers Streams API 활용)

에러: 404 / 410 — §7 참조.

---

## 7. 에러 코드 및 HTTP 상태

> **[SPEC-UNDEFINED: 에러 응답 본문 스키마 미정의]** — 권장 형식은 §9.4 참조.

| HTTP 상태 | 의미 | 주요 발생 엔드포인트 | 출처 |
|----------|------|-------------------|------|
| 200 | 성공 | 모든 GET, PUT | — |
| 201 | 생성 성공 | POST /api/share, POST /photos | — |
| 204 | 성공 (본문 없음) | DELETE /photos/{photoId} | — |
| 400 | 잘못된 요청 (파라미터 누락/형식 오류) | 모든 POST/PUT | — |
| 401 | editToken 불일치 또는 PIN 미인증 | PUT, DELETE, PIN 보호 GET | 01-SPEC.md:277-278 |
| 403 | 권한 부족 (드문 케이스) | — | — |
| 404 | shortId 또는 photoId 없음 | 모든 엔드포인트 | — |
| 410 | viewer 만료 (생성 후 7일 경과, KV/R2 자동 삭제) | 모든 엔드포인트 | 01-SPEC.md:126 |
| 413 | 페이로드 초과 (사진 1장 10MB 초과 등) | POST /photos, POST /api/share | 01-SPEC.md:279 |
| 429 | Rate limit 초과 (deviceToken 기준 1분 5건) | POST /api/share | 01-SPEC.md:280 |
| 500 | Worker 내부 오류 | 모든 엔드포인트 | — |

---

## 8. Rate Limiting 및 보안 제약

| 규칙 | 값 | 출처 |
|------|----|------|
| POST /api/share Rate limit | deviceToken 당 1분 5건 | 01-SPEC.md:280 |
| POST /photos Rate limit | [SPEC-UNDEFINED: 권장안 §9.5 참조] | — |
| round JSON 최대 크기 | [SPEC-UNDEFINED: 권장 1MB] — POST /api/share 의 413 트리거 조건 | — |
| PIN 오답 잠금 | 5회 오답 시 1시간 잠금 | 01-SPEC.md:278 |
| 사진 1장 최대 크기 | 10MB | 01-SPEC.md:279 |
| viewer당 사진 최대 수 | 30장 | 01-SPEC.md:279 |
| shortId 형식 | base62 8자 (218조 경우의 수) | 01-SPEC.md:276 |
| editToken | Worker 생성 후 KV 저장. 디바이스 외부 노출 금지 | 01-SPEC.md:277 |
| PIN 저장 방식 | bcrypt 해시 저장 (cost factor는 33-SECURITY.md 위임) | 01-SPEC.md:278 |
| PII 차단 | 동반자 실명/연락처 업로드 거부 | 01-SPEC.md:282, CLAUDE.md §PROJECT |
| 전송 보안 | HTTPS only (Cloudflare 자동 적용) | 01-SPEC.md:281 |
| deviceToken | 익명 UUID — 외부 전송하지 않으며 서버 측 Rate limiting에만 사용 | 01-SPEC.md:670 |

---

## 통계 공유 API (v1, 2026-05-27)

> 아래 6개 엔드포인트는 "통계 공유" 기능에 해당한다. 라운드 공유(`/api/share`)와 같은 3토큰 모델을 사용하되 KV namespace와 shortId prefix를 분리한다.
>
> **v2 (2026-07-17) — og:image 추가**: TC-1에 optional `ogImage` 필드, TC-6 `GET /og/:shortId.png` 신설. iOS가 렌더한 카드 PNG를 KV에 저장해 카톡 미리보기로 서빙한다. **PIN 보호 공유는 og를 저장·서빙하지 않는다**(미리보기로 스코어가 새는 것을 막기 위함).

### TC-1. POST /api/share/stats (통계 공유 생성)

```
POST /api/share/stats
Content-Type: application/json
```

통계 페이로드를 `KV_STATS`에 저장하고 shortId + URL + editToken을 반환한다.

#### 요청

```json
{
  "deviceToken": "550e8400-e29b-41d4-a716-446655440000",
  "payload": {
    "cardKind": "pr",
    "signature": {
      "headline": "개인 최고 기록 갱신",
      "bigNumber": "78",
      "bigUnit": "타",
      "deltaText": "-3타 신기록",
      "metaPrimary": "한양 CC · 2026-05-27",
      "metaSecondary": null,
      "footerLabel": "라운드온으로 기록됨"
    },
    "summary": {
      "totalRounds": 24,
      "recentAverageScore": 88.2,
      "averageVsPar": 16.2
    },
    "scoreDistribution": {
      "eagleOrBetter": 0,
      "birdie": 12,
      "par": 95,
      "bogey": 180,
      "doubleOrWorse": 145,
      "totalHoles": 432,
      "comment": "파 유지율 22% · 꾸준한 성장 중"
    },
    "parAverages": [
      { "par": 3, "averageScore": 3.8, "vsPar": 0.8, "holeCount": 96 },
      { "par": 4, "averageScore": 5.1, "vsPar": 1.1, "holeCount": 240 },
      { "par": 5, "averageScore": 6.5, "vsPar": 1.5, "holeCount": 96 }
    ],
    "trend": {
      "direction": "improving",
      "directionLabel": "↘ 좋아지는 중",
      "previousAverage": 92.0,
      "currentAverage": 88.2,
      "delta": -3.8,
      "scoreTrend": [94, 91, 90, 89, 88],
      "sigmaText": null
    },
    "bestRound": {
      "courseName": "한양 컨트리클럽",
      "dateISO": "2026-05-27",
      "totalScore": 78,
      "isPersonalRecord": true
    },
    "regions": [
      { "displayName": "경기도", "roundCount": 14, "centroidLat": 37.4, "centroidLng": 127.5 }
    ],
    "recentRounds": [
      { "courseName": "한양 CC", "dateISO": "2026-05-27", "totalScore": 78, "vsPar": 6, "holeCount": 18 }
    ],
    "displayName": "홍길동",
    "createdAtISO": "2026-05-27T09:00:00Z",
    "periodLabel": "최근 6개월 · 24라운드"
  },
  "pin": "1234"
}
```

**필드 설명**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `deviceToken` | string (UUID) | 필수 | 익명 UUID — Rate limiting 기준. 외부 노출 없음 |
| `payload` | `StatsSharePayload` | 필수 | 통계 viewer 전체 페이로드 (`Worker/src/types.ts` 정의 참조) |
| `payload.cardKind` | `"pr" \| "hcp" \| "trend"` | 필수 | 시그니처 카드 종류 |
| `payload.signature` | `StatsSignature` | 필수 | hero 카드 내용 (headline/bigNumber/bigUnit 등) |
| `payload.summary` | `StatsSummary` | 필수 | 요약 3카드 수치 |
| `payload.scoreDistribution` | `StatsDistribution` | 필수 | 스코어 분포 + 파율 도넛 |
| `payload.parAverages` | `StatsParAverage[]` | 필수 | Par3/4/5 평균 (바 차트) |
| `payload.trend` | `StatsTrend \| null` | 선택 | 최근 흐름 + sparkline |
| `payload.bestRound` | `StatsBestRound \| null` | 선택 | 베스트 라운드 |
| `payload.regions` | `StatsRegionShare[]` | 필수 | 시도 centroid 기반 지역 목록 |
| `payload.recentRounds` | `StatsRecentEntryShare[]` | 필수 | 최근 라운드 목록 (최대 5건 표시) |
| `payload.displayName` | string | 필수 | 닉네임 (PII 마스킹 iOS Builder + Worker 양쪽 적용) |
| `payload.createdAtISO` | string (ISO 8601) | 필수 | iOS 생성 시각 |
| `payload.periodLabel` | string | 필수 | 통계 기간 라벨 (예: "최근 6개월 · 24라운드") |
| `pin` | string (4자리 숫자) | 선택 | PIN 보호 설정 시. Worker에서 bcrypt 해시 저장 |
| `ogImage` | string (base64) | 선택 | **v2** — og:image용 1080×1080 시그니처 카드 PNG. data URI prefix 없는 순수 base64. 상한 1,572,864자 |

**페이로드 크기 한도**: `payload` 1MB (초과 시 413 `PAYLOAD_TOO_LARGE`). body 전체 한도는 2,662,400 bytes (payload 1MB + ogImage 1.5MB + 여유).

**`ogImage` 실패 정책 (v2)**: og 관련 문제는 **공유 생성을 막지 않는다**. 상한 초과 / base64 디코드 실패 / PNG 매직바이트 불일치 / PIN 설정됨 — 어느 경우든 **201로 공유는 생성되고 og만 생략**된다. 응답에 og 관련 필드가 없으므로 앱은 저장 성공 여부를 알 수 없다(서버 로그 `[stats:og] 저장 거부 … reason=`로만 확인).

#### 응답 201

```json
{
  "shortId": "s_aB3dE7fG",
  "url": "https://golf.zerolive.co.kr/s/s_aB3dE7fG",
  "editToken": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
  "expiresAt": "2026-06-03T09:00:00Z"
}
```

| 응답 필드 | 설명 |
|----------|------|
| `shortId` | `s_` prefix + base62 8자 = 총 10자 |
| `url` | 통계 viewer 전체 URL (`/s/` prefix) |
| `editToken` | 수정/삭제용 32자 hex 토큰. iOS Keychain 저장 필수 |
| `expiresAt` | 생성 시점 + 7일 (ISO 8601 UTC). TTL 영구 보관 없음 |

에러: 400 / 413 / 429 — §7 참조.

**인증**: `deviceToken` (바디) — Rate limiting 기준. 1분 5건 한도.

---

### TC-2. GET /s/:shortId (통계 viewer HTML)

```
GET /s/s_aB3dE7fG
```

통계 viewer HTML을 반환한다. PIN 설정 여부에 따라 분기한다.

- 응답 `Content-Type`: `text/html; charset=utf-8`
- `Cache-Control: private, max-age=0, must-revalidate`

**분기**:

| 조건 | Worker 동작 |
|------|------------|
| PIN 없음 (공개) | 통계 viewer 전체 HTML 응답 (200) |
| PIN 있음, 쿠키 `stats_pin_ok_{shortId}` 유효 | 통계 viewer 전체 HTML 응답 (200) |
| PIN 있음, 쿠키 없음 | PIN 잠금 화면 HTML 응답 (200) |
| shortId 없음 또는 형식 불일치 | 404 HTML |
| 만료됨 (7일 경과, KV TTL 만료) | 410 HTML |

shortId 정규식: `^s_[0-9A-Za-z]{8}$`

viewer HTML 구조 및 CSS 디테일은 `31-VIEWER_HTML.md §10` 참조.

---

### TC-3. PUT /api/share/stats/:shortId (통계 공유 부분 업데이트)

```
PUT /api/share/stats/s_aB3dE7fG
Authorization: Bearer {editToken}
Content-Type: application/json
```

기존 shortId를 유지하면서 payload 또는 PIN을 갱신한다.

#### 헤더

```
Authorization: Bearer {editToken}
```

33-SECURITY §3.2 형식 확정.

#### 요청 (partial update)

```json
{
  "payload": {
    "displayName": "홍**"
  },
  "pin": "5678"
}
```

- `payload`: `StatsSharePayload` 의 부분 필드만 포함 가능 (top-level 병합)
- `pin`: `"1234"` → PIN 갱신. `null` 또는 `""` → PIN 제거. 생략 시 PIN 변경 없음
- `expiresAt`는 원래 생성 시점 기준으로 유지 (갱신으로 TTL 연장 없음)

#### 응답 200

```json
{
  "shortId": "s_aB3dE7fG",
  "url": "https://golf.zerolive.co.kr/s/s_aB3dE7fG",
  "expiresAt": "2026-06-03T09:00:00Z"
}
```

에러: 400 / 401 (editToken 불일치) / 404 / 410 (만료) — §7 참조.

---

### TC-4. DELETE /api/share/stats/:shortId (통계 공유 삭제)

```
DELETE /api/share/stats/s_aB3dE7fG
Authorization: Bearer {editToken}
```

KV_STATS에서 `stats:{shortId}` 키를 즉시 삭제한다. TTL 만료 전 수동 회수 시 사용한다.

#### 헤더

```
Authorization: Bearer {editToken}
```

#### 응답 204

본문 없음.

에러: 401 (editToken 불일치) / 404 (shortId 없음) — §7 참조.

> **참고 (v2 갱신)**: 통계 공유에는 사진/R2 자원이 없다. 단 v2부터 og:image가 있으므로 KV 키를 2개(`stats:{shortId}`, `stats:{shortId}:og`) 삭제한다.

---

### TC-6. GET /og/:shortId.png (통계 og:image 서빙) — v2

```
GET /og/s_aB3dE7fG.png
```

TC-1에서 `ogImage`로 업로드된 1080×1080 카드 PNG를 서빙한다. **카톡 등 크롤러 전용** — 앱이 직접 호출할 일은 없다. viewer HTML의 `<meta property="og:image">`가 이 URL을 가리킨다.

#### 응답 200

```
Content-Type: image/png
Cache-Control: public, max-age=604800, immutable
```

#### 404를 반환하는 경우

| 사유 | 설명 |
|------|------|
| og 미업로드 | v1 공유 또는 `ogImage` 미전송 (하위 호환) |
| **PIN 보호** | `meta.pinHash` 존재 시 — 매 요청 재검사한다 |
| 만료 | 7일 TTL 경과 (페이로드와 동일 수명) |
| 형식 오류 | shortId가 `s_` + base62 8자 형식이 아님 |

> **라우팅 순서 주의**: `/og/*`는 `/:shortId` catch-all보다 **앞**에 배치해야 한다 (`router.ts`).
>
> **PIN 3중 방어**: ①생성 시 저장 skip ②서빙 시 `pinHash` 재검사 404 ③렌더 시 og 메타 미출력. 잠금 화면(`renderStatsPinLock`)은 og 태그를 전혀 출력하지 않으므로 크롤러는 내용을 볼 수 없다.
>
> **구조적 한계 (해결 불가)**: 공개로 공유한 뒤 **나중에** PIN을 걸어도, 카톡이 og 이미지를 자기 CDN에 독립 캐싱하므로 **이미 대화방에 뿌려진 미리보기는 회수되지 않는다**. 서버 차단으로 해결되지 않는 영역 — 사용자 고지로 대응한다(2026-07-17 결정). 단 현재 iOS에는 사후 PIN 설정 경로(TC-3 PUT) 자체가 미구현이라 실제 발생 경로는 없다.

---

### TC-5. POST /s/:shortId/verify-pin (통계 viewer PIN 검증)

```
POST /s/s_aB3dE7fG/verify-pin
Content-Type: application/json
```

통계 viewer의 PIN 잠금 화면에서 호출하는 검증 엔드포인트. 성공 시 세션 쿠키를 발급한다.

#### 요청

```json
{ "pin": "1234" }
```

#### 응답 표

| HTTP | 조건 | 바디 | 추가 헤더 |
|------|------|------|----------|
| 200 | PIN 일치 | `{ "ok": true }` | `Set-Cookie: stats_pin_ok_{shortId}=1; Max-Age=86400; HttpOnly; SameSite=Lax; Path=/` |
| 401 | PIN 불일치 (잠금 전) | `{ "ok": false, "attempts": N, "locked": false }` | — (300ms 고정 지연 후 응답) |
| 429 | 5회 오답 잠금 | `{ "ok": false, "locked": true, "retryAfter": 3600 }` | `Retry-After: 3600` |
| 400 | PIN 형식 오류 | `{ "error": "PIN_INVALID_FORMAT" }` | — |

**인증**: PIN bcrypt 검증 (cost 12, `bcryptjs` — 33-SECURITY §4 참조)

**잠금 키**: `pinlock:stats:{shortId}:{CF-Connecting-IP}` — IP 기반 1차 잠금 (33-SECURITY §5.2 정책 동일 적용)

**세션 쿠키**: `stats_pin_ok_{shortId}` (라운드 공유의 `viewer_session`과 분리)

| 쿠키 속성 | 값 |
|----------|-----|
| `Max-Age` | `86400` (24시간) |
| `HttpOnly` | `true` |
| `SameSite` | `Lax` |
| `Path` | `/` |

> 라운드 공유 PIN 쿠키(`viewer_session`)와 다른 이름/속성을 사용한다. 쿠키 충돌 없음.

---

### TC-6. shortId prefix 및 KV namespace 분리 정책

| 항목 | 라운드 공유 | 통계 공유 |
|------|-----------|---------|
| shortId prefix | 없음 (순수 base62 8자) | `s_` + base62 8자 = 10자 |
| shortId 예시 | `aB3dE7fG` | `s_aB3dE7fG` |
| URL 경로 | `https://golf.zerolive.co.kr/{shortId}` | `https://golf.zerolive.co.kr/s/{shortId}` |
| KV namespace | `KV_META` | `KV_STATS` |
| KV 키 패턴 | `share:{shortId}` | `stats:{shortId}` |
| TTL | 7일 | 7일 (영구 보관 없음) |
| PIN 잠금 키 | `pinlock:{shortId}:{ip}` | `pinlock:stats:{shortId}:{ip}` |
| 세션 쿠키 이름 | `viewer_session` | `stats_pin_ok_{shortId}` |
| 편집 토큰 형식 | `tok_` + base64url 32자 | 순수 32자 hex |

**KV_STATS wrangler.toml binding**: `PLACEHOLDER_REPLACE_AFTER_CREATE` → Worker DEPLOYMENT.md §STATS_KV 참조.

### TC-7. og:image 정적 3장 정책

통계 viewer의 `<meta property="og:image">` 는 cardKind에 따라 정적 3장 중 하나를 참조한다.

| cardKind | og:image URL |
|----------|-------------|
| `pr` | `https://golf.zerolive.co.kr/og-stats-pr.png` |
| `hcp` | `https://golf.zerolive.co.kr/og-stats-hcp.png` |
| `trend` | `https://golf.zerolive.co.kr/og-stats-trend.png` |

**규격**: 1200×630 (Open Graph 표준), PNG, 200KB 이하 권장.
**배치 방법**: Worker DEPLOYMENT.md §og-image 섹션 참조.

실시간 이미지 생성(Puppeteer/Satori 등)은 v1 범위 밖이다. v2 검토 사항.

---

## 9. 구현 제안 (spec 외)

본 섹션은 `01-SPEC.md`에 없는 구현 권장안이며, 실제 결정은 구현 단계 또는 후속 문서에서 확정한다. 본 문서가 명세화하지 않는다.

### 9.1 사진 업로드 형식 [SPEC-UNDEFINED]

`multipart/form-data` 방식을 권장한다. Cloudflare Workers의 R2 스트리밍 PUT과 친화적이며, 바이너리 데이터를 base64로 인코딩하는 오버헤드(33%)를 제거할 수 있다.

- 1차 권장: `multipart/form-data` + Worker의 `request.formData()` 파싱
- Fallback: iOS 클라이언트가 multipart를 지원하지 못하는 경우 `{ "photo": "<base64>", "mimeType": "image/jpeg" }` JSON 바디 허용

### 9.2 PIN 검증 엔드포인트 [SPEC-UNDEFINED]

PIN 보호 viewer 진입 시 처리 방식:

권장 엔드포인트:
```
POST /:shortId/unlock
```

요청 바디:
```json
{ "pin": "1234" }
```

- 성공 시: 단기 세션 쿠키 또는 임시 서명 토큰 발급 → 이후 `GET /:shortId` 접근 시 Worker가 쿠키/토큰 검증 후 HTML 응답
- 실패 시: 401 반환. 5회 누적 오답 시 1시간 잠금 (01-SPEC.md:278). 잠금 키 차원(`CF-Connecting-IP` vs 세션 토큰 vs deviceToken)은 `33-SECURITY.md` (작성 예정)에 위임.
- PIN 해시 비교는 KV에 저장된 bcrypt 해시와 대조 (01-SPEC.md:278)

### 9.3 round JSON 페이로드 구조 [SPEC-UNDEFINED]

POST /api/share 및 PUT /api/share/{shortId} 에서 전달하는 `round` 객체의 와이어 스키마가 01-SPEC.md에 정의되어 있지 않다. 최소 필드 기준: `id / date / courseName / startedAt / finishedAt / totalScore / players[] / holes[]` — `21-DATA_MODEL.md` §2의 @Model 구조를 기준으로 직렬화 코드 작성 시 확정한다.

SwiftData @Model에는 존재하지만 와이어에서 제외될 가능성이 있는 필드(예: 로컬 전용 플래그, CloudKit 내부 메타데이터, HealthKit UUID 등)는 후속 직렬화 작업 시 **21-DATA_MODEL §3 ↔ 와이어 차이 표**로 별도 정리 — TODO.

### 9.4 에러 응답 스키마 [SPEC-UNDEFINED]

권장 에러 응답 바디: `{ "error": "ERROR_CODE_ENUM", "message": "사람이 읽을 수 있는 설명" }`

권장 에러 코드 Enum 후보: `PIN_REQUIRED` / `PIN_INVALID` / `PIN_LOCKED` / `EDIT_TOKEN_INVALID` / `EXPIRED` / `NOT_FOUND` / `RATE_LIMITED` / `PAYLOAD_TOO_LARGE` / `PII_REJECTED` / `INTERNAL_ERROR`

### 9.5 POST /photos Rate Limit [SPEC-UNDEFINED]

spec_3.md는 `POST /api/share` Rate limit만 명시한다 (01-SPEC.md:280). 사진 업로드에 대한 별도 Rate limit 권장안:

- deviceToken 당 1분 30건 (viewer당 최대 30장 제약과 동일 수준)
- R2 대역폭 보호 목적으로 IP 기반 추가 제한 병행 고려

### 9.6 라운드 전체 DELETE 엔드포인트 [SPEC-UNDEFINED]

01-SPEC.md에 정의 없음. 권장: `DELETE /api/share/{shortId}` + `Authorization: Bearer {editToken}` 헤더. 성공 시 KV 메타데이터 + R2 사진 전체 삭제 → 204 반환. 앱 측은 204 수신 후 Round의 `sharedShortId / sharedURL / sharedExpiresAt / sharedEditToken` 4개 필드를 nil 처리한다. (21-DATA_MODEL §8)

### 9.7 Idempotency-Key 및 OpenAPI 산출물

- **Idempotency-Key 헤더**: 네트워크 재시도 시 POST /api/share 중복 생성 방지 목적. Worker가 동일 키 감지 시 기존 응답 반환 (24시간 KV TTL).
- **OpenAPI 3.1 YAML**: 본 문서를 `ref-docs/specs/30-API_SPEC.yaml`로도 관리하여 iOS 클라이언트 / Worker 코드 자동 생성 도구와 연계 권장.

---

## 부록: 후속 보완 TODO 및 책임 경계

**spec 미정의 5건 (라운드 공유)**: (1) 라운드 DELETE §9.6 / (2) PIN 검증 §9.2 / (3) round 페이로드 구조 §9.3 / (4) 에러 응답 스키마 §9.4 / (5) 사진 업로드 형식 §9.1

**문서 책임 경계**:

| 문서 | 담당 영역 |
|------|----------|
| **본 문서 (30-API_SPEC)** | HTTP 엔드포인트 (라운드 7개 + 통계 5개), 인증 모델, 에러 코드, Rate limiting |
| `21-DATA_MODEL.md` (작성 완료) | SwiftData 모델 스키마, Viewer 공유 필드 원본 정의 |
| `31-VIEWER_HTML.md` | `GET /:shortId` 응답 HTML 구조 (라운드) + `GET /s/:shortId` HTML 구조 (통계) |
| `32-CLOUDFLARE_SETUP.md` (작성 예정) | KV 네임스페이스, wrangler.toml, TTL 설정 |
| `33-SECURITY.md` | bcrypt cost factor, PII 패턴 매칭 정규식 디테일, 잠금 정책 세부 |
| `Worker/DEPLOYMENT.md` | KV_STATS 발급 가이드, og:image 배치 가이드 |

---

*최종 업데이트: 2026-05-27 (통계 공유 v1 — TC-1~TC-7 추가)*

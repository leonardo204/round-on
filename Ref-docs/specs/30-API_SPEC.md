# 30 — API 명세 (Cloudflare Worker)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [21-DATA_MODEL](21-DATA_MODEL.md) · [31-VIEWER_HTML](31-VIEWER_HTML.md) · [32-CLOUDFLARE_SETUP](32-CLOUDFLARE_SETUP.md) · [33-SECURITY](33-SECURITY.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §3.3 (01-SPEC.md:259-284), §9 (01-SPEC.md:655-672)
> **관련 문서**: `21-DATA_MODEL.md` (SwiftData 모델), `31-VIEWER_HTML.md`, `32-CLOUDFLARE_SETUP.md`, `33-SECURITY.md`

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
- **OpenAPI 3.1 YAML**: 본 문서를 `Ref-docs/specs/30-API_SPEC.yaml`로도 관리하여 iOS 클라이언트 / Worker 코드 자동 생성 도구와 연계 권장.

---

## 부록: 후속 보완 TODO 및 책임 경계

**spec 미정의 5건**: (1) 라운드 DELETE §9.6 / (2) PIN 검증 §9.2 / (3) round 페이로드 구조 §9.3 / (4) 에러 응답 스키마 §9.4 / (5) 사진 업로드 형식 §9.1

**문서 책임 경계**:

| 문서 | 담당 영역 |
|------|----------|
| **본 문서 (30-API_SPEC)** | HTTP 엔드포인트 7개, 인증 모델, 에러 코드, Rate limiting |
| `21-DATA_MODEL.md` (작성 완료) | SwiftData 모델 스키마, Viewer 공유 필드 원본 정의 |
| `31-VIEWER_HTML.md` (작성 예정) | `GET /:shortId` 응답 HTML 구조, CSS, 갤러리 인터랙션 |
| `32-CLOUDFLARE_SETUP.md` (작성 예정) | KV 네임스페이스, R2 버킷, wrangler.toml, TTL 설정 |
| `33-SECURITY.md` (작성 예정) | bcrypt cost factor, PII 패턴 매칭 정규식 디테일, 잠금 정책 세부 |

---

*최종 업데이트: 2026-05-11*

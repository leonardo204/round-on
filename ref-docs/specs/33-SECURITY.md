# 33 — 보안 정책 (Security)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [30-API_SPEC](30-API_SPEC.md) · [31-VIEWER_HTML](31-VIEWER_HTML.md) · [32-CLOUDFLARE_SETUP](32-CLOUDFLARE_SETUP.md) · [50-PRIVACY_POLICY](50-PRIVACY_POLICY.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §3.4 (01-SPEC.md:274-284), §9 (01-SPEC.md:655-672)
> **관련 문서**: `30-API_SPEC.md`, `21-DATA_MODEL.md`, `31-VIEWER_HTML.md`, `32-CLOUDFLARE_SETUP.md`, `53-PERMISSIONS.md`

---

> **본 문서가 정식 확정한 결정 5건**
>
> 본 문서는 `30-API_SPEC.md` / `21-DATA_MODEL.md` / `53-PERMISSIONS.md`가 위임한 보안 결정을 정식 확정한다:
>
> 1. bcrypt cost = 12 (§4)
> 2. editToken 헤더 형식 = `Authorization: Bearer {editToken}` (§3)
> 3. PIN 검증 엔드포인트 = `POST /:shortId/verify-pin` + 세션 쿠키 (§5)
> 4. PIN 잠금 키 = `pinlock:{shortId}:{ip}` 1차 + `{shortId}:{viewer_session}` 보조 (§5)
> 5. PII 정책 = 4종 정규식 매칭 시 차단 X, 서버측 마스킹 후 저장 (§7)

---

## 1. 목적 / 범위

본 문서는 라운드온 Cloudflare Worker의 **서버측 보안 결정 단일 SoT(Source of Truth)**이다. 아래 영역의 구체적 결정을 본 문서에서 확정하고, 동료 문서는 이 문서를 참조한다.

**다루는 영역**: shortId 생성, editToken 생성·검증, PIN 해싱·잠금, Rate limiting, PII 마스킹, 전송 보안, 데이터 보존·삭제

**위임 영역 표**:

| 위임 영역 | 담당 문서 |
|----------|----------|
| HTTP 엔드포인트 요청/응답 구조 | `30-API_SPEC.md` |
| SwiftData 모델, Viewer 공유 필드 | `21-DATA_MODEL.md` |
| viewer HTML 구조, CSP, PIN 입력 화면 | `31-VIEWER_HTML.md` |
| KV/R2 네임스페이스, wrangler.toml, TTL 설정 | `32-CLOUDFLARE_SETUP.md` (작성 예정) |
| iOS Info.plist 권한 키, usage string | `53-PERMISSIONS.md` |

---

## 2. shortId 생성 정책

### 2.1 포맷

- 문자 집합: base62 (`a-z`, `A-Z`, `0-9`) 8자 (01-SPEC.md:276)
- 경우의 수: 62^8 = 약 218조 (218,340,105,584,896)

### 2.2 생성 알고리즘

```
crypto.getRandomValues(Uint8Array(6))  →  base62 인코딩  →  8자 shortId
```

6바이트 = 48비트 엔트로피. base62 인코딩 시 8자를 얻기 위해 마지막 자리 mod 처리를 적용한다.

### 2.3 충돌 검사 정책

**충돌 검사 생략** (Architect 권장안 반영): 218조 경우의 수에서 1억 viewer를 발급해도 생일 충돌 확률은 약 0.002%이므로 실용적으로 무시 가능하다. KV `PUT`을 직접 실행하고, 사후 모니터링(일일 발급량 KV 카운터)만 수행한다. 충돌 사후 감지 시 Worker 재시도 1회를 구현 단계에서 검토할 수 있다.

---

## 3. editToken 생성·전송·저장

### 3.1 생성

```
crypto.getRandomValues(Uint8Array(24))  →  base64url 인코딩  →  'tok_' prefix 부착
```

결과 형식 예시: `tok_AbCdEfGhIjKlMnOpQrStUvWx`  (32자 suffix + prefix 4자 = 36자)

### 3.2 전송 형식 (정식 확정)

`30-API_SPEC §4`가 잠정 채택한 표기를 본 문서가 정식 확정한다:

```
Authorization: Bearer {editToken}
```

`X-Edit-Token` 등 커스텀 헤더 방안은 채택하지 않는다.

### 3.3 서버측 저장

- **KV 키**: `share:{shortId}` 메타 객체 내 `editToken` 필드 (평문)
- **TTL**: 7일 (21-DATA_MODEL §8, 01-SPEC.md:669)
- editToken은 서버측 비밀이다. viewer HTML·사진 응답에 절대 노출하지 않는다.
- `31-VIEWER_HTML.md`의 CSP가 editToken 노출을 방어한다.

### 3.4 클라이언트 저장

- iOS Keychain 권장 키: `kr.co.zerolive.roundon.editToken.{shortId}`
- Keychain `kSecAttrAccessible = kSecAttrAccessibleWhenUnlocked`

### 3.5 Idempotency-Key 보안

- Idempotency-Key로는 deviceToken 해시만 저장한다. PII를 포함하지 않는다.
- 키만으로 권한(편집/삭제)을 부여하지 않는다. 모든 변경 요청은 `Authorization: Bearer {editToken}` 검증을 통과해야 한다.
- KV TTL: 24시간 (30-API §9.7)

---

## 4. PIN 해싱 및 검증

### 4.1 알고리즘

| 항목 | 값 | 근거 |
|------|-----|------|
| 알고리즘 | bcrypt | 01-SPEC.md:278 |
| cost factor | **12** (사용자 확정) | Workers Unbound 환경 적합 |
| 라이브러리 | `bcryptjs` (WASM 없는 pure-JS 구현) | Workers 환경 호환 |

### 4.2 성능 특성

- cost 12 기준 p95 응답 시간: **약 200-300ms** (Workers Unbound 가정, 실측 필요)
- `bcryptjs` Workers 환경 벤치마크는 §10 구현 제안 참조

### 4.3 Timing Attack 방지

**401 응답을 300ms 고정 지연으로 통일**한다:

- bcrypt 비교 실패 시 즉시 반환하지 않고 300ms까지 지연 후 401 응답
- 이유: bcrypt 내부 시간 차이로 PIN 존재 여부가 누출되는 것을 방지
- 구현: `const startedAt = Date.now(); /* ... bcrypt.compare ... */ const elapsed = Date.now() - startedAt; await new Promise(r => setTimeout(r, Math.max(0, 300 - elapsed)));`

### 4.4 입력 검증

- 허용 패턴: `[0-9]{4}` (정확히 4자리 숫자)
- 패턴 불일치 시: `400 PIN_INVALID_FORMAT` 즉시 반환 (타이밍 지연 불필요)

### 4.5 KV 저장 키

- **키**: `share:{shortId}:pinHash`
- 메타 객체(`share:{shortId}`)와 분리하여 저장한다.
- PIN을 설정하지 않은 viewer에는 이 키가 존재하지 않는다.

### 4.6 약한 PIN 경고 (선택)

아래 10개 PIN은 Worker에서 403 또는 경고 응답 반환을 권장한다 (구현 단계 결정):

`0000`, `1111`, `2222`, `3333`, `4444`, `5555`, `6666`, `7777`, `8888`, `9999`, `1234`, `4321`

---

## 5. PIN 오답 잠금 정책 + 세션 쿠키

### 5.1 잠금 정책

- 5회 오답 누적 시 1시간 잠금 (01-SPEC.md:278)
- KV 값: `{ "attempts": <int>, "firstAttemptAt": <unix_ts> }`
- TTL: 3600초 (1시간). 잠금 해제는 TTL 만료로 자동 처리한다.

### 5.2 잠금 키 구조 (IP 1차 + session 보조)

**1차 카운터 키 (보안 실효성)**:

```
pinlock:{shortId}:{CF-Connecting-IP}
```

- `CF-Connecting-IP` 헤더에서 클라이언트 IP를 추출한다.
- 쿠키를 삭제해도 IP 기반 카운터는 리셋되지 않는다. 이것이 보안 실효성을 보장하는 핵심이다.

**보조 관측 키 (UX/디버그)**:

```
{shortId}:{viewer_session}
```

- 세션 쿠키 값을 키로 사용한다.
- 카운터 증감에는 사용하지 않으며, UX 통계·디버그 목적으로만 관측한다.

**이유**: 쿠키 삭제만으로 PIN 오답 카운터를 리셋할 수 있는 우회 경로를 차단하기 위해 IP를 1차 키로 사용한다. VPN 전환 시 카운터 우회가 가능하나, viewer가 단기 공유 링크임을 고려하면 이 수준의 보호로 충분하다.

### 5.3 PIN 검증 엔드포인트 (정식 확정)

`30-API_SPEC §9.2`의 권장안(`POST /:shortId/unlock`)을 본 문서가 다음과 같이 정식 확정한다:

```
POST /:shortId/verify-pin
```

**요청**:

```http
POST /aB3dE7fG/verify-pin
Content-Type: application/json

{ "pin": "1234" }
```

**응답 표**:

| HTTP | 조건 | 바디 | 추가 헤더 |
|------|------|------|----------|
| 200 | PIN 일치 | `{ "ok": true }` | `Set-Cookie: viewer_session=...` (§5.4) |
| 401 | PIN 불일치 (잠금 전) | `{ "ok": false, "attempts": N, "locked": false }` | — (300ms 지연 후 응답) |
| 429 | 5회 오답 잠금 | `{ "ok": false, "locked": true, "retryAfter": 3600 }` | `Retry-After: 3600` |
| 400 | PIN 형식 오류 | `{ "error": "PIN_INVALID_FORMAT" }` | — |

### 5.4 세션 쿠키 속성 표

| 속성 | 값 | 이유 |
|------|-----|------|
| `HttpOnly` | `true` | XSS로 쿠키 탈취 방지 |
| `Secure` | `true` | HTTPS 전송만 허용 |
| `SameSite` | `Strict` | CSRF 방지 |
| `Max-Age` | `900` (15분) | viewer 단기 접근 세션에 적합 |
| `Path` | `/{shortId}` | 다른 shortId viewer와 쿠키 범위 분리 |

쿠키 이름: `viewer_session`

### 5.5 세션 쿠키 검증 흐름

```
GET /:shortId
  → Worker: viewer_session 쿠키 확인
    → 유효(서명 검증 통과, 만료 전): 스코어카드 HTML 응답
    → 무효/없음: PIN 잠금 화면 HTML 응답
```

세션 쿠키 서명: HMAC-SHA256 (`{shortId}:{iat}:{random}`, Worker secret key 사용). 서명 없이 단순 값만 저장하면 위조 가능하므로 서명이 필수다.

---

## 6. Rate Limiting 알고리즘

### 6.1 알고리즘

**Sliding Window Counter** — Cloudflare KV의 TTL 기능을 활용한다.

구현 방식:
1. 현재 분(floor to minute) 기준 KV 키에 카운터 증가
2. TTL을 70초(1분 윈도우 + 10초 버퍼)로 설정
3. 카운터가 한도 초과 시 429 반환

### 6.2 규칙 표

| 엔드포인트 | 한도 | KV 키 패턴 | 출처 |
|----------|------|-----------|------|
| `POST /api/share` | 1분 5건 | `rl:share:{deviceToken}:{yyyyMMddHHmm}` | 01-SPEC.md:280 |
| `POST /api/share/{shortId}/photos` | 1분 30건 | `rl:photos:{deviceToken}:{yyyyMMddHHmm}` | 30-API §9.5 정식 확정 |
| `POST /:shortId/verify-pin` | §5 PIN 잠금 정책에 흡수 | `pinlock:{shortId}:{ip}` | 본 문서 §5 |

### 6.3 거부 응답

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60
Content-Type: application/json

{ "error": "RATE_LIMITED", "message": "요청 한도를 초과했습니다. 잠시 후 다시 시도하세요." }
```

---

## 7. PII 패턴 매칭 (마스킹 정책)

### 7.1 검사 대상

- `players[].name` 필드 (모든 플레이어 이름)
- 캡션 필드 (향후 구현 시 적용)

### 7.2 정책: 차단 X, 서버측 마스킹 후 저장

**차단 정책을 채택하지 않는 이유**: 라운드온은 친구 공유 컨텍스트 앱이다. 연락처가 포함된 텍스트를 차단하면 사용자 경험이 단절된다. PII가 감지되면 마스킹 처리 후 저장하여 viewer에 표시한다.

### 7.3 정규식 4종

| 패턴 | 정규식 | 마스킹 결과 |
|------|--------|-----------|
| 한국 휴대전화 | `` `01[016789][-\s]?\d{3,4}[-\s]?\d{4}` `` | `***-****-****` |
| 이메일 | `` `[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}` `` | `***@***.***` |
| 주민등록번호 | `` `\d{6}[-\s]?[1-4]\d{6}` `` | `******-*******` |
| 신용카드 16자리 | `` `(?:\d[ -]*?){13,16}` `` | `****-****-****-****` |

**신용카드 패턴은 Luhn 알고리즘 추가 검증 필수**: 골프 점수 시퀀스(예: "5 4 5 4 3 4 5 4 5 4 5 4 3" = 13자리 숫자)나 전화번호 변형 등 13자리 이상 숫자 시퀀스 false positive를 막기 위해 Luhn 검증을 통과한 경우에만 마스킹 적용. (Reviewer 권장)

### 7.4 예외 케이스 표

**매칭 (마스킹 처리)**:

| 입력 | 매칭 패턴 | 마스킹 결과 |
|------|----------|-----------|
| `010-1234-5678` | 한국 휴대전화 | `***-****-****` |
| `010 9876 5432` | 한국 휴대전화 | `***-****-****` |
| `test@example.com` | 이메일 | `***@***.***` |
| `hong@company.co.kr` | 이메일 | `***@***.***` |
| `123456-1234567` | 주민등록번호 | `******-*******` |

**비매칭 (마스킹 없이 저장)**:

| 입력 | 비매칭 이유 |
|------|-----------|
| `010 화이팅` | 4자리 블록 미완성 |
| `abc@dotcom` | TLD 누락 (점 없음) |
| `1234567` | 7자리, 주민번호 패턴 미충족 |
| `홍길동` | 한국 실명 패턴 미채택 (false positive 과다) |
| `민준` | 한국 실명 패턴 미채택 (별명 차단 회피) |

### 7.5 한국 실명 패턴 미채택 근거

한국 2-3자 이름 정규식은 "민준", "지수" 같은 일반 별명도 매칭하여 false positive가 과다하다. 실명 마스킹은 채택하지 않는다.

### 7.6 클라이언트 측 1차 차단

`53-PERMISSIONS §8` 보강 TODO로 표기한다. 클라이언트 측에서 1차 PII 차단 가이드를 추가하는 것을 권장한다 (§10 참조).

### 7.7 통계 공유 v1 PII 정책 (2026-05-27 추가 / 2026-05-27 갱신)

통계 공유 v1(`StatsSharePayload`)에 §7.1~§7.4 마스킹 정책이 동일하게 적용된다. 추가로 다음 제약이 있다.

**닉네임 마스킹 이중 적용**:
- **iOS Builder 1차**: `StatsSharePayloadBuilder.swift`에서 `displayName` 필드를 §7.3 정규식으로 마스킹 후 Worker에 전송
- **Worker 2차**: `POST /api/share/stats` handler에서 `payload.displayName`을 다시 §7.3 정규식으로 검증·마스킹 후 KV 저장

**위치 정보 정책 (2026-05-27 갱신)**:

| 필드 | 허용 여부 | 조건 |
|------|----------|------|
| `StatsRegionShare.centroidLat/Lng` | 허용 | 시도(광역시·도) centroid 좌표만 — RegionCentroidLUT 참조 |
| `StatsRoundLocationShare.lat/lng` | **조건부 허용** | 사용자가 명시적으로 공유 버튼을 누른 경우에 한함 |

**조건부 허용 근거** (`StatsRoundLocationShare`):
- 사용자가 통계 공유 버튼을 누르는 행위는 **본인 라운드 골프장 좌표 노출에 동의**한 것으로 해석한다.
- 동반자/제3자 위치가 아닌, **본인 라운드 이력에 포함된 골프장의 클럽하우스 좌표** (공개된 시설 위치)에 한해 허용한다.
- `StatsSharePayload.roundLocations`는 `Optional` 필드로, 사용자 공유 시점에만 iOS Builder가 주입한다.

**여전히 차단되는 필드**:

| 필드 | 이유 |
|------|------|
| 동반자 이름(`players[].name`) | 제3자 개인정보 |
| 라운드 ID(`roundId`) | 개별 라운드 추적 가능 |
| `courseId` | payload JSON 키로 노출 금지 (내부 식별자 역할) |
| `deviceId` / `deviceToken` (응답에 미포함) | 디바이스 식별 |

`deviceToken`은 Rate limiting용으로 Worker에 전송되지만 KV 저장된 메타(`StatsShareMeta.deviceToken`)는 rate-limit 추적 목적으로만 보존되며 viewer HTML에 절대 노출하지 않는다.

**viewer HTML PII 검증 기준**:
viewer HTML 소스에서 다음 키워드가 발견되면 PII 가드 위반으로 간주한다:
`courseId`, `deviceId`, `deviceToken`, `roundId`

> 참고: `roundLocations` 안의 `lat/lng` 수치는 조건부 허용 대상이므로, viewer HTML에 포함되어도 위반이 아니다 (단, `courseId` 키는 여전히 금지).

---

## 8. 전송 보안 (HTTPS / 헤더)

### 8.1 HTTPS

- HTTPS only: Cloudflare 자동 적용 (01-SPEC.md:281)
- HTTP 요청은 Cloudflare에서 자동으로 HTTPS로 리다이렉트된다.

### 8.2 HSTS

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

### 8.3 viewer HTML 응답 보안 헤더

| 헤더 | 값 | 목적 |
|------|----|------|
| `X-Content-Type-Options` | `nosniff` | MIME 스니핑 방지 |
| `Referrer-Policy` | `no-referrer` | 리퍼러 정보 누출 방지 |
| `Permissions-Policy` | `geolocation=(), camera=()` | 불필요한 권한 차단 |
| `Strict-Transport-Security` | (§8.2 참조) | HTTPS 강제 |

**CSP (Content Security Policy)**: viewer HTML CSP 정의는 `31-VIEWER_HTML.md`에 위임한다. CSP가 editToken·쿠키 등의 민감 정보가 서드파티로 누출되지 않도록 방어하는 것을 `31-VIEWER_HTML.md`가 책임진다.

---

## 9. 데이터 보존 및 삭제

### 9.1 TTL 기반 자동 만료

| 데이터 | TTL | KV/R2 | 출처 |
|--------|-----|--------|------|
| viewer 메타 (shortId, PIN 해시 등) | 7일 | KV | 01-SPEC.md:669, 21-DATA_MODEL §8 |
| viewer 사진 | 7일 | R2 | 01-SPEC.md:669 |
| PIN 오답 잠금 카운터 | 1시간 | KV | 01-SPEC.md:278 |
| Rate limit 카운터 | 70초 | KV | 본 문서 §6 |
| 세션 쿠키 | 15분 | 브라우저 | 본 문서 §5.4 |
| Idempotency-Key | 24시간 | KV | 30-API §9.7 |

### 9.2 사용자 명시 삭제

`DELETE /api/share/{shortId}` 수신 즉시:
1. `share:{shortId}` KV 메타 삭제
2. `share:{shortId}:pinHash` KV 삭제
3. R2 사진 전체 삭제 (`{shortId}/photo/*`)
4. `204 No Content` 응답

클라이언트(iOS 앱)는 204 수신 후 Round 객체의 `sharedShortId / sharedURL / sharedExpiresAt / sharedEditToken` 4개 필드를 nil 처리한다. (21-DATA_MODEL §8)

### 9.3 로그 마스킹 규칙

- PIN 평문, editToken 평문, IP 원본: Workers 로그에 기록 금지
- editToken 로깅 형식: `editToken=tok_***` (prefix 유지, suffix 마스킹)
- PII: §7 정규식 매칭 카운트만 기록. 원본 값 미저장
- CF-Connecting-IP: Rate limit 카운터 키에만 사용. 로그에 기록하지 않는다.

### 9.4 deviceToken 처리

- 익명 UUID (01-SPEC.md:670)
- Rate limit 카운터 키에만 사용
- 외부 서비스 전송 금지. 서버 로그에 원본 기록 금지.

---

## 10. 책임 경계 + 구현 제안 (spec 외)

본 §10 일부 항목은 01-SPEC.md에 없는 보강 권장안이며, 실제 결정은 구현 단계에서 확정한다. 본 문서가 명세화하지 않는다.

### 10.1 본 문서가 확정한 위임 결정 5건

(헤더 박스와 동일, 참조 편의를 위해 재명시)

1. bcrypt cost = 12 (§4)
2. editToken 헤더 형식 = `Authorization: Bearer {editToken}` (§3)
3. PIN 검증 엔드포인트 = `POST /:shortId/verify-pin` + 세션 쿠키 (§5)
4. PIN 잠금 키 = `pinlock:{shortId}:{ip}` 1차 + `{shortId}:{viewer_session}` 보조 (§5)
5. PII 정책 = 4종 정규식 매칭 시 마스킹 후 저장 (§7)

### 10.2 책임 경계 표

| 문서 | 담당 영역 |
|------|----------|
| **본 문서 (33-SECURITY)** | shortId/editToken 생성, PIN 해싱·잠금, Rate limiting, PII 마스킹, HTTPS 헤더, 데이터 보존·삭제 |
| `20-ARCHITECTURE.md` | 시스템 컴포넌트 다이어그램, GolfCourse 아키텍처 결정 |
| `21-DATA_MODEL.md` | SwiftData @Model 스키마, Viewer 공유 필드 원본 정의 |
| `30-API_SPEC.md` | HTTP 엔드포인트 7개의 요청/응답 계약 |
| `31-VIEWER_HTML.md` | viewer HTML 마크업, CSP, PIN 입력 화면 fetch 흐름 |
| `32-CLOUDFLARE_SETUP.md` (작성 예정) | KV/R2 네임스페이스, wrangler.toml, TTL 세부 설정 |
| `53-PERMISSIONS.md` | iOS Info.plist 권한 키, usage string |
| `42-COURSE_ADMIN_TOOL.md` (작성 예정, 선택) | 어드민 도구 보안 정책 |

### 10.3 구현 제안 (spec 외)

아래 항목은 01-SPEC.md에 없는 보강 권장안이다.

**bcryptjs Workers 벤치마크**: cost 12 기준 실측 응답 시간을 Workers 환경에서 측정하여 p50/p95/p99를 기록한다. 300ms 고정 지연 정책(§4.3)의 적정성을 실측값으로 검증한다.

**Cloudflare Turnstile 도입 검토**: PIN 잠금 화면에 Turnstile(봇 차단) 위젯 추가를 검토한다. 자동화된 PIN 브루트포스를 IP 차단 이전 단계에서 차단할 수 있다.

**shortId 일일 발급량 모니터링**: KV 카운터(`stats:share:{yyyyMMdd}`)로 일일 viewer 생성량을 추적한다. 비정상적 급증 시 알림을 설정한다.

**세션 쿠키 HMAC 키 관리**: HMAC-SHA256 서명에 사용하는 Worker secret key는 Cloudflare Workers Secret(`wrangler secret put`)으로 관리한다. 소스코드 또는 wrangler.toml에 하드코딩을 금지한다.

### 10.4 후속 보완 TODO

| 항목 | 담당 | 우선순위 |
|------|------|---------|
| 53-PERMISSIONS §8에 클라이언트 측 1차 PII 차단 가이드 추가 | 53-PERMISSIONS 담당 | 권장 |
| 31-VIEWER_HTML §8 본 작업으로 동기 패치 완료 | 확인 완료 | 완료 |
| bcryptjs Workers cost 12 실측 벤치마크 | 구현 단계 | 권장 |
| Cloudflare Turnstile 도입 검토 | 구현 단계 | 선택 |
| shortId 모니터링 KV 카운터 구현 | 구현 단계 | 권장 |

---

*최종 업데이트: 2026-05-27 (§7.7 통계 공유 v1 PII 정책 추가)*

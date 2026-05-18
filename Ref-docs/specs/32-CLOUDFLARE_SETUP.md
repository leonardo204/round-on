# 32 — Cloudflare 인프라 셋업 (Cloudflare Setup)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [30-API_SPEC](30-API_SPEC.md) · [31-VIEWER_HTML](31-VIEWER_HTML.md) · [33-SECURITY](33-SECURITY.md) · [21-DATA_MODEL](21-DATA_MODEL.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §3.2 (01-SPEC.md:244-258), §3.4 (01-SPEC.md:274-284)
> **관련 문서**: `30-API_SPEC.md`, `31-VIEWER_HTML.md`, `33-SECURITY.md`, `21-DATA_MODEL.md`, `50-PRIVACY_POLICY.md`
>
> ⚠️ **2026-05-18 폐기 사항**: §4 R2 버킷(`R2_PHOTOS`) + Lifecycle Rule 모두 제거. 사진 공유 기능 자체가 폐기되어 R2 인프라 불필요. 본 문서의 §4 전체는 무효. KV 4종 / wrangler.toml / Custom Domain 설정은 그대로 유효 (`Worker/DEPLOYMENT.md`가 최신 가이드).
> §6 DNS는 더 단순한 **Custom Domain 방식**으로 대체됨 (대시보드 → Worker → Settings → Domains & Routes).

---

> **본 문서 정식 확정 5건**
>
> 동료 문서가 위임한 인프라 결정을 본 문서에서 정식 확정한다.
>
> 1. **KV 네임스페이스 4종 + 키 스키마** (`KV_META`, `KV_RATELIMIT`, `KV_PINLOCK`, `KV_SESSION`) — §3
> 2. ~~**R2 버킷 1종**~~ — **2026-05-18 폐기**
> 3. **wrangler.toml 완전 구성** (바인딩 + 환경 + 시크릿) — §5
> 4. **DNS CNAME + Worker 라우트** (`golf.zerolive.co.kr`) — §6 (Custom Domain으로 대체)
> 5. **보안 헤더 적용 위치** (Worker 응답 전역) — §8

---

## 1. 목적 / 범위

본 문서는 라운드온 Cloudflare Worker, KV, R2, DNS 인프라를 **재현 가능하게** 셋업하기 위한 단일 참조 문서이다.

**다루는 영역**: Cloudflare Workers 배포 구성, KV 네임스페이스 4종, R2 버킷, DNS CNAME/라우트, 보안 헤더 적용 위치, TTL 자동 삭제, 모니터링 권고.

**다루지 않는 영역** (위임):

| 문서 | 담당 영역 |
|------|----------|
| `30-API_SPEC.md` | HTTP 엔드포인트 계약, 요청/응답 구조 |
| `31-VIEWER_HTML.md` | viewer HTML 마크업, CSS, CSP 디테일 |
| `33-SECURITY.md` | bcrypt cost, PIN 검증 알고리즘, PII 마스킹 |
| `21-DATA_MODEL.md` | Round SwiftData 스키마, sharedShortId 등 4필드 |
| `50-PRIVACY_POLICY.md` | Cloudflare 처리 위탁 명시, 보유기간 공개 |

**가정**: Cloudflare 계정 보유, `zerolive.co.kr` 도메인 Cloudflare DNS 등록 완료 (CLAUDE.md §PROJECT), `wrangler` CLI 설치 및 `wrangler login` 완료, API Token에 Workers/KV/R2/Route 편집 권한 부여.

---

## 2. 아키텍처 개요

라운드온 Cloudflare 인프라 구성 요소와 데이터 흐름 (01-SPEC.md §3.2):

```
[iPhone 앱] ──── HTTPS POST/PUT ──► golf.zerolive.co.kr
                                          ▼
                              ┌─────────────────────────┐
                              │   Cloudflare Worker      │
                              │   (roundon-viewer)       │
                              └────────┬─────────────┬───┘
                                       ▼             ▼
                              [KV: 메타/상태]    [R2: 사진]
                              roundon-meta        roundon-photos
                              roundon-ratelimit   {shortId}/{photoId}.jpg
                              roundon-pinlock     (7일 Lifecycle Rule)
                              roundon-session

[브라우저] ──── HTTPS GET ──► golf.zerolive.co.kr/{shortId}
                                          ▼
                              Worker → KV 메타 조회
                              PIN 보호 시: verify-pin (33-SECURITY §5)
                              사진: R2 직접 응답
```

**무료 티어 기준** (01-SPEC.md:254): KV 100k reads/day · 1k writes/day, R2 10GB + 1M class A/월, Workers 100k req/day.

---

## 3. KV 네임스페이스 정식 확정

`30-API_SPEC §1` 위임 수신. KV 네임스페이스 이름, 바인딩명, 키 스키마를 본 절에서 정식 확정한다.

| 네임스페이스 | 바인딩명 | 용도 | TTL |
|------------|--------|------|-----|
| `roundon-meta` | `KV_META` | shortId → 메타 JSON (round, options, editToken, expiresAt) | `expirationTtl: 604800` (7일) |
| `roundon-ratelimit` | `KV_RATELIMIT` | Rate limit 카운터 (33-SECURITY §6) | `expirationTtl: 70` (70초) |
| `roundon-pinlock` | `KV_PINLOCK` | PIN 오답 잠금 카운터 (33-SECURITY §5) | `expirationTtl: 3600` (1시간) |
| `roundon-session` | `KV_SESSION` | viewer 세션 쿠키 검증값 (33-SECURITY §5.4) | `expirationTtl: 900` (15분) |

**키 스키마**:

```
KV_META:       share:{shortId}                      → 메타 JSON
               share:{shortId}:pinHash              → bcrypt 해시 (33-SECURITY §4.5)
KV_RATELIMIT:  rl:share:{deviceToken}:{minute}      → 정수 (viewer 생성 카운터)
               rl:photos:{deviceToken}:{minute}     → 정수 (사진 업로드 카운터)
KV_PINLOCK:    pinlock:{shortId}:{CF-Connecting-IP} → { attempts, firstAttemptAt }
KV_SESSION:    session:{sessionId}                  → { shortId, createdAt }
```

`share:{shortId}:pinHash`는 PIN 설정 viewer에만 존재한다. `expirationTtl`은 KV `put` 호출 시 옵션으로 전달한다.

**생성 명령** (출력 `id`를 §5 wrangler.toml에 기재):

```bash
wrangler kv:namespace create roundon-meta
wrangler kv:namespace create roundon-ratelimit
wrangler kv:namespace create roundon-pinlock
wrangler kv:namespace create roundon-session
```

---

## 4. R2 버킷 정식 확정

`30-API_SPEC §1` 위임 수신. R2 버킷, 바인딩명, Lifecycle Rule을 본 절에서 정식 확정한다.

| 버킷 | 바인딩명 | 용도 | TTL |
|------|--------|------|-----|
| `roundon-photos` | `R2_PHOTOS` | 사진 파일 (viewer 공유 시) | Lifecycle Rule 7일 자동 삭제 |

**키 스키마**: `{shortId}/{photoId}.jpg` (photoId = 앱 측 UUID, 21-DATA_MODEL §3 `RoundPhoto.id`)

**생성 및 Lifecycle Rule** (21-DATA_MODEL §8, 01-SPEC.md:250):

```bash
wrangler r2 bucket create roundon-photos

wrangler r2 bucket lifecycle put roundon-photos --rules '{
  "rules": [{ "id": "expire-7-days", "status": "Enabled", "expiration": { "days": 7 } }]
}'
```

R2 Lifecycle은 매일 1회 처리 — 삭제까지 최대 +24시간 지연. KV 메타가 먼저 만료되어 접근이 차단되므로 실질적 보안은 KV TTL 기준으로 보장된다.

**CORS** (Cloudflare 대시보드 → R2 → `roundon-photos` → Settings → CORS Policy):

```json
{
  "AllowedOrigins": ["https://golf.zerolive.co.kr"],
  "AllowedMethods": ["GET"],
  "AllowedHeaders": ["*"],
  "MaxAgeSeconds": 3600
}
```

---

## 5. wrangler.toml 구성

`30-API_SPEC §1` 위임 수신. wrangler.toml 완전 구성을 본 절에서 정식 확정한다.

```toml
name = "roundon-viewer"
main = "src/index.ts"
compatibility_date = "2026-05-11"
compatibility_flags = ["nodejs_compat"]

# Workers Unbound: bcrypt cost 12 처리 (~200-300ms) 허용 (33-SECURITY §4.2)
usage_model = "unbound"
workers_dev = true

[env.production]
route = { pattern = "golf.zerolive.co.kr/*", zone_name = "zerolive.co.kr" }
workers_dev = false

[[kv_namespaces]]
binding = "KV_META"
id = "<roundon-meta ID>"

[[kv_namespaces]]
binding = "KV_RATELIMIT"
id = "<roundon-ratelimit ID>"

[[kv_namespaces]]
binding = "KV_PINLOCK"
id = "<roundon-pinlock ID>"

[[kv_namespaces]]
binding = "KV_SESSION"
id = "<roundon-session ID>"

[[r2_buckets]]
binding = "R2_PHOTOS"
bucket_name = "roundon-photos"

[vars]
ENVIRONMENT = "production"
VIEWER_DOMAIN = "golf.zerolive.co.kr"
```

**시크릿** (wrangler.toml에 절대 기재 금지, `wrangler secret put`으로 등록):

```bash
# bcrypt 추가 보안용 pepper (선택 — 33-SECURITY §4 보강)
wrangler secret put BCRYPT_PEPPER --env production
```

**타입스크립트 바인딩 타입** (`src/types.ts`):

```typescript
export interface Env {
  KV_META: KVNamespace;
  KV_RATELIMIT: KVNamespace;
  KV_PINLOCK: KVNamespace;
  KV_SESSION: KVNamespace;
  R2_PHOTOS: R2Bucket;
  ENVIRONMENT: string;
  VIEWER_DOMAIN: string;
  BCRYPT_PEPPER?: string;
}
```

---

## 6. DNS 및 라우트 설정

`golf.zerolive.co.kr` Worker 라우트 설정 절차 (CLAUDE.md §PROJECT, 01-SPEC.md:252).

**CNAME 레코드** (Cloudflare 대시보드 → DNS → Add Record):

| 항목 | 값 |
|------|-----|
| Type | `CNAME` |
| Name | `golf` |
| Target | `roundon-viewer.<account-subdomain>.workers.dev` |
| Proxy | 켜짐 (오렌지 구름) — 반드시 활성화 |
| TTL | Auto |

Proxy가 꺼진 DNS only 상태에서는 Worker가 개입하지 않는다. wrangler.toml의 `route` 설정은 `wrangler deploy` 시 자동 등록된다.

```bash
wrangler deploy --env production

# 배포 검증
curl -I https://golf.zerolive.co.kr/healthz
wrangler route list --env production
```

**SSL/TLS 설정** (대시보드 → SSL/TLS):

| 항목 | 권장값 |
|------|-------|
| SSL/TLS 모드 | Full (strict) |
| Always Use HTTPS | ON (01-SPEC.md:281) |
| HSTS | 활성화 권장 (§8 HSTS 헤더와 이중 적용) |
| Minimum TLS | 1.2 이상 |

---

## 7. TTL 자동 삭제 동작 검증

`21-DATA_MODEL §6` 위임 수신. TTL 적용 방법을 본 절에서 정식 확정한다. 아래 표는 `50-PRIVACY_POLICY §4` 보유기간 표와 일치한다.

| 데이터 | 저장소 | TTL 값 | 적용 방식 | 삭제 지연 |
|------|-------|-------|---------|---------|
| viewer 메타데이터 | KV `KV_META` | 604800 (7일) | `expirationTtl` | ~10분 내 |
| viewer 사진 | R2 `R2_PHOTOS` | 7일 | Lifecycle Rule | 최대 +24시간 |
| Rate limit 카운터 | KV `KV_RATELIMIT` | 70초 | `expirationTtl` | ~10분 내 |
| PIN 잠금 카운터 | KV `KV_PINLOCK` | 3600 (1시간) | `expirationTtl` | ~10분 내 |
| viewer 세션 | KV `KV_SESSION` | 900 (15분) | `expirationTtl` | ~10분 내 |
| Idempotency-Key | KV `KV_META` | 86400 (24시간) | `expirationTtl` | ~10분 내 |

**KV TTL 적용 코드 패턴**:

```typescript
// viewer 메타 저장 — 7일 TTL
await env.KV_META.put(
  `share:${shortId}`,
  JSON.stringify(meta),
  { expirationTtl: 604800 }
);
// PIN 해시 — 동일 TTL
await env.KV_META.put(
  `share:${shortId}:pinHash`,
  pinHash,
  { expirationTtl: 604800 }
);
```

---

## 8. 보안 헤더 적용

`33-SECURITY §8` 위임 수신. 보안 헤더 적용 위치를 본 절에서 정식 확정한다. 모든 헤더는 **Worker 응답 전역**에 부착한다.

```typescript
// src/index.ts
function applySecurityHeaders(response: Response): Response {
  const h = new Headers(response.headers);
  h.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  h.set('X-Content-Type-Options', 'nosniff');
  h.set('Referrer-Policy', 'no-referrer');
  h.set('Permissions-Policy', 'geolocation=(), camera=(), microphone=()');
  h.set('X-Frame-Options', 'DENY');
  return new Response(response.body, { status: response.status, headers: h });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return applySecurityHeaders(await handleRequest(request, env));
  },
};
```

viewer HTML의 CSP(`Content-Security-Policy`) 헤더 값 정의는 `31-VIEWER_HTML.md` 담당. JSON API 응답에는 CSP를 적용하지 않는다.

**Cloudflare 대시보드 추가 설정**:

| 항목 | 위치 | 권장값 |
|------|------|-------|
| Always Use HTTPS | SSL/TLS → Edge Certificates | ON |
| HSTS | SSL/TLS → Edge Certificates | 활성화 |
| Bot Fight Mode | Security → Bots | 활성화 (선택) |
| Rate Limiting Rules | Security → WAF | Worker 수준(33-SECURITY §6)과 별개로 전역 추가 |

---

## 9. 모니터링 / 로깅

**Workers Analytics** (대시보드 → Workers & Pages → `roundon-viewer`):

| 지표 | 점검 주기 |
|------|---------|
| 요청 수 / 5xx 에러율 | 이상 감지 즉시 |
| CPU 시간 p95/p99 | 주 1회 (bcrypt cost 12 기준) |
| KV read/write 사용량 | 주 1회 |
| R2 스토리지 / class A | 월 1회 |

**로그 마스킹** (`33-SECURITY §9`): Worker 로그에 editToken · PIN · IP 평문 기록 금지.

```typescript
// 올바른 마스킹
console.log(`[share] shortId=${shortId} editToken=tok_***`);
console.log(`[pin] shortId=${shortId} ip=${ip.substring(0, 6)}***`);
```

**알람 권고** (Cloudflare Notifications):

| 조건 | 임계값 |
|------|-------|
| 5분간 5xx 비율 | 5% 초과 |
| Workers CPU 한도 근접 | 80% |
| R2 스토리지 | 9GB (90%) |
| KV write 일 사용량 | 900건 (90%) |

**Logpush** (선택): 외부 SIEM 필요 시 R2 또는 외부 엔드포인트로 설정. [SPEC-UNDEFINED: 대상 미정] — 배포 단계에서 결정한다.

---

## 10. [SPEC-UNDEFINED] 및 책임 경계

### 본 문서 정식 확정 5건

| 번호 | 확정 내용 | 절 |
|------|----------|-----|
| 1 | KV 네임스페이스 4종 (`roundon-meta` 외 3종) + 바인딩명 + 키 스키마 | §3 |
| 2 | R2 버킷 `roundon-photos` + `R2_PHOTOS` + Lifecycle Rule 7일 + CORS | §4 |
| 3 | wrangler.toml 완전 구성 (바인딩, 환경, 시크릿 등록 방법) | §5 |
| 4 | DNS CNAME `golf` + Worker 라우트 + SSL Full(strict) | §6 |
| 5 | 보안 헤더 Worker 응답 전역 적용 위치 | §8 |

### [SPEC-UNDEFINED] 항목

| 항목 | 설명 | 확정 시점 |
|------|------|---------|
| Cloudflare 계정 ID / Zone ID | wrangler.toml `<ID>` 플레이스홀더 실제 값 | 최초 배포 전 |
| BCRYPT_PEPPER 값 | `openssl rand -base64 32` 생성 후 `wrangler secret put` | 최초 배포 직전 |
| Logpush 대상 | 외부 SIEM 또는 R2 여부 | 배포 단계 |
| CDN 캐싱 세부 규칙 | viewer HTML = `private, no-store` 권장, 사진 = R2 직접 응답 | 31-VIEWER_HTML.md 작성 시 |

### 책임 경계

| 문서 | 담당 영역 |
|------|----------|
| **본 문서 (32-CLOUDFLARE_SETUP)** | KV/R2/Worker/DNS 셋업, wrangler.toml, TTL 적용 위치, 보안 헤더 Worker 적용 위치 |
| `30-API_SPEC.md` | HTTP 엔드포인트 계약, 요청/응답 구조, Rate limit 규칙 정의 |
| `31-VIEWER_HTML.md` | viewer HTML 마크업, CSS, CSP 헤더 값 정의 |
| `33-SECURITY.md` | bcrypt cost 12, PIN 검증 로직, PII 마스킹 알고리즘, editToken 생성 |
| `21-DATA_MODEL.md` | Round SwiftData 스키마, sharedShortId 등 viewer 공유 4필드 원본 정의 |
| `50-PRIVACY_POLICY.md` | Cloudflare 처리 위탁 명시 (§5.2), 보유기간 공개 표 (§4) |

### 후속 보완 TODO

- 최초 배포 전 Cloudflare 계정 ID / Zone ID를 wrangler.toml에 확정 기재
- `wrangler kv:namespace create` 출력 ID를 CI 환경변수 또는 git-secret으로 관리
- BCRYPT_PEPPER 시크릿 생성 및 등록
- Logpush 대상 결정 후 §9 업데이트
- R2 Lifecycle Rule wrangler CLI 지원 여부 확인 (미지원 시 대시보드 또는 Cloudflare API로 대체)

---

*최종 업데이트: 2026-05-11*

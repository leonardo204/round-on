# 라운드온 Worker 배포 가이드

`zerolive.co.kr` 도메인 + `golf.zerolive.co.kr` subdomain에 viewer Worker를 배포하는 전체 절차.

---

## 현재 진행 상태 (2026-05-18)

| 단계 | 상태 | 비고 |
|------|------|------|
| 1. wrangler login | ✅ 완료 | account: `e23e7abfddf68800ec7837de23c22990` |
| 2. KV 네임스페이스 4종 | ✅ 완료 | ID는 §3 |
| 3. wrangler.toml KV ID 치환 + env.production bindings 명시 | ✅ 완료 | setup.sh 자동 |
| 4. 시크릿 등록 (SESSION_HMAC_KEY, BCRYPT_PEPPER) | ✅ 완료 | §4 |
| 5. ~~R2 + 사진 핸들러~~ | ❌ **2026-05-18 완전 폐기** | 사진 공유 기능 자체 제거 — 개인정보보호 + 비용 절감 |
| 6. **Worker deploy** | ✅ **완료** | `roundon-viewer-production` 등록 (사진 코드 제거 후 재배포 필요) |
| 7. **Cloudflare 대시보드 → Worker → Custom Domain `golf.zerolive.co.kr`** | ❌ **사용자 액션 필요** | §6 |
| 8. `curl https://golf.zerolive.co.kr/healthz` 확인 | ⏳ Custom Domain 추가 후 |

---

## 1. 사전 준비

```bash
cd /Users/zerolive/work/golfCounter/Worker
npm install
npx wrangler login    # 브라우저로 Cloudflare 로그인
npx wrangler whoami   # 확인
```

---

## 2. setup.sh — 자동화된 셋업 스크립트

```bash
bash scripts/setup.sh
```

이 스크립트가 자동으로 처리하는 것:
- KV 네임스페이스 4개 생성 (또는 기존 ID 조회)
- 추출된 ID를 `wrangler.toml`에 자동 치환 (백업: `wrangler.toml.bak`)
- R2 버킷 `roundon-photos` 생성 시도 (R2 활성화 안 됐으면 안내)
- R2 Lifecycle Rule (7일 만료) 설정 시도

자동 처리 불가 항목:
- R2 계정 활성화 (사용자 직접)
- 시크릿 등록 (보안상 직접 paste)
- DNS CNAME 설정 (대시보드)
- 최종 deploy

---

## 3. KV 자원 (자동 등록 완료)

setup.sh 실행 결과로 자동 생성/치환된 KV ID들:

| Binding | Cloudflare title | ID |
|---------|-------|----|
| `KV_META` | `roundon-viewer-ROUNDON_META` | `7b78e911dd704dd29c684002b99247af` |
| `KV_RATELIMIT` | `roundon-viewer-ROUNDON_RATELIMIT` | `7c656f66ceef450584018031f6ad0413` |
| `KV_PINLOCK` | `roundon-viewer-ROUNDON_PINLOCK` | `61235bd0592e467f812bb548488b77c9` |
| `KV_SESSION` | `roundon-viewer-ROUNDON_SESSION` | `c80cc35640444de4b3a3eef50a554ec3` |

`wrangler.toml`의 `[[kv_namespaces]]` 및 `[[env.production.kv_namespaces]]` 양쪽에 모두 반영됨.

---

## 4. 시크릿 (자동 등록 완료)

```bash
# SESSION_HMAC_KEY (세션 쿠키 HMAC-SHA256 서명)
# BCRYPT_PEPPER    (PIN bcrypt pepper)
```

`npx wrangler secret list --env production` 으로 등록 확인 가능.

값은 Cloudflare Worker 안에서만 접근 가능 (외부 조회 불가). 갱신 필요 시:
```bash
echo "$(openssl rand -base64 32)" | npx wrangler secret put SESSION_HMAC_KEY --env production
echo "$(openssl rand -base64 32)" | npx wrangler secret put BCRYPT_PEPPER --env production
```

⚠️ 갱신 시 기존 발급된 viewer 세션/PIN 모두 무효화됨.

---

## 5. ⚠️ R2 활성화 (사용자 액션 필요)

**현재 R2가 계정에서 비활성 상태** — Cloudflare는 R2 사용 전에 명시적 활성화를 요구합니다.

### 단계
1. Cloudflare 대시보드 (https://dash.cloudflare.com) → 로그인
2. 좌측 사이드바 → **R2** 클릭
3. **"Get started" 또는 "Sign up to R2"** 버튼 클릭
4. 무료 플랜 (Class A 1M req/월, Class B 10M req/월, 10GB 저장) 약관 동의
5. 결제 카드 등록 (무료 한도 안 넘으면 청구 없음)

### 활성화 후
```bash
bash scripts/setup.sh   # 다시 실행 → 버킷 자동 생성 + lifecycle 설정
```

R2 버킷 lifecycle CLI 명령이 실패하면 수동 설정:
- 대시보드 → R2 → `roundon-photos` → Settings → **Lifecycle Rules**
- Add rule:
  - **Action**: Expire current versions of objects
  - **Days after upload**: 7
- Save

---

## 6. ⚠️ Custom Domain 추가 (Worker deploy 후 사용자 액션)

### 사전 확인
`npx wrangler deploy --env production`가 성공해서 Worker가 등록되어 있어야 합니다.

### 단계 (Cloudflare 대시보드)
1. https://dash.cloudflare.com → 로그인
2. 좌측 사이드바 → **Workers & Pages**
3. `roundon-viewer-production` Worker 클릭 (방금 배포된 것)
4. 상단 탭 → **Settings**
5. 좌측 메뉴 → **Domains & Routes** (또는 **Triggers**)
6. **Add** 버튼 → **Custom Domain** 선택 (Route 아님)
7. Domain: `golf.zerolive.co.kr` 입력
8. **Add Domain** 클릭
9. Cloudflare가 자동으로:
   - DNS AAAA `100::` 레코드 생성 (Proxied)
   - Worker route 등록
   - SSL 인증서 발급 (~1분)

⏳ 1~2분 후 `curl https://golf.zerolive.co.kr/healthz`로 확인.

---

## 7. SSL/TLS 한 번만 확인

1. Cloudflare 대시보드 → `zerolive.co.kr` → **SSL/TLS**
2. Overview: **Full (strict)**
3. Edge Certificates:
   - Always Use HTTPS: **ON**
   - Minimum TLS Version: **1.2**
   - HSTS: **Enable**

---

## 8. 최종 배포

```bash
cd /Users/zerolive/work/golfCounter/Worker
npx wrangler deploy --env production
```

출력 예시:
```
Deployed roundon-viewer triggers
  https://golf.zerolive.co.kr/*
```

---

## 9. 동작 확인

```bash
# 헬스체크
curl -i https://golf.zerolive.co.kr/healthz
# → HTTP/2 200, body: {"status":"ok",...}

# 전체 스모크 테스트 (R2 버킷 활성화 + 배포 완료 후)
bash scripts/smoke-test.sh
```

iOS 앱에서:
1. 라운드 종료 → 상세 → "공유하기"
2. URL 생성 (`https://golf.zerolive.co.kr/<shortId>` 형식)
3. Safari에서 URL 열어 viewer HTML 확인

---

## 10. 트러블슈팅

### "Please enable R2" 에러
→ §5 R2 활성화 단계 수행

### "kv:namespace" 명령 unknown
→ wrangler v4부터 `kv namespace` (콜론 제거). setup.sh는 이미 수정됨

### DNS 변경 후 즉시 안 통하면
→ 최대 5분 propagation 대기. `dig golf.zerolive.co.kr` 로 CNAME 확인

### "There doesn't seem to be a Worker called roundon-viewer-production"
→ 첫 deploy 전 secret 등록 시 발생 가능 — Worker가 secret과 함께 자동 생성됨. 무시 OK

### bindings env 경고
→ `wrangler.toml`의 `[env.production]` 안에 `kv_namespaces`/`r2_buckets`/`vars` 명시 필요. 이미 수정됨

---

## 11. account ID

```
Cloudflare Account ID: e23e7abfddf68800ec7837de23c22990
Zone: zerolive.co.kr
Subdomain: golf.zerolive.co.kr
Worker name: roundon-viewer (production: roundon-viewer-production)
```

---

## 12. 백업 / 복구

- `wrangler.toml.bak` — setup.sh 첫 실행 시 자동 백업
- KV/R2 데이터는 Cloudflare 측 저장. 자체 백업 정책 별도 (운영 단계 검토)

---

---

## STATS_KV namespace 발급 (통계 공유 v1, 2026-05-27)

`KV_STATS` binding은 통계 공유 v1 엔드포인트(`POST /api/share/stats`, `GET /s/:shortId` 등)에서 사용한다. 기존 `KV_META`(라운드 공유)와 완전히 분리된 namespace이다.

### 발급 순서

1. dev용 발급:
   ```bash
   cd /Users/zerolive/work/golfCounter/Worker
   npx wrangler kv namespace create KV_STATS
   ```
   출력 예시:
   ```
   Add the following to your configuration file in your kv_namespaces array:
   { binding = "KV_STATS", id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }
   ```

2. production용 발급:
   ```bash
   npx wrangler kv namespace create KV_STATS --env production
   ```

3. 발급된 ID를 `wrangler.toml`에서 `PLACEHOLDER_REPLACE_AFTER_CREATE` 자리에 교체:
   ```toml
   # dev
   [[kv_namespaces]]
   binding = "KV_STATS"
   id = "<dev에서 발급된 ID>"

   # production
   [[env.production.kv_namespaces]]
   binding = "KV_STATS"
   id = "<production에서 발급된 ID>"
   ```

4. 배포:
   ```bash
   npx wrangler deploy --env production
   ```

5. 확인:
   ```bash
   npx wrangler kv namespace list --env production
   # KV_STATS binding이 목록에 표시되어야 함
   ```

### TTL 정책

KV_STATS 저장 키: `stats:{shortId}` (JSON, 7일 TTL)

Worker handler에서 `expirationTtl: 604800` (7일 = 7 × 86400초)로 자동 설정된다. Cloudflare KV TTL 만료 후 키가 자동 삭제된다.

---

## og:image 정적 자산 배치 {#og-image}

통계 viewer의 og:image는 cardKind별 정적 PNG 3장을 참조한다:

| 파일명 | cardKind | 카드 내용 |
|--------|----------|---------|
| `og-stats-pr.png` | `pr` | 개인 최고 기록 (PR) 카드 |
| `og-stats-hcp.png` | `hcp` | 핸디캡 하락 카드 |
| `og-stats-trend.png` | `trend` | 최근 흐름 개선 카드 |

**권장 사이즈**: 1200×630 (Open Graph 표준), PNG, 200KB 이하

**배치 방법 (3가지 옵션 중 택1)**:

- **(옵션 A) Cloudflare Pages 연계**: Pages 프로젝트 `/public/` 디렉토리에 배치 후 `golf.zerolive.co.kr` 도메인에 연결. Pages 정적 자산이 Worker 요청보다 우선 서빙됨.

- **(옵션 B) Workers Sites**: `wrangler.toml`에 `[site] bucket = "./public"` 설정 후 `./public/og-stats-*.png` 배치. `wrangler deploy` 시 자동 업로드.
  ```toml
  [site]
  bucket = "./public"
  ```

- **(옵션 C) 외부 CDN**: Cloudflare Images 또는 R2 Public Bucket 업로드 후 URL을 `statsViewer.ts`의 ogImage 생성 로직에 하드코딩.

**v1 임시 방안**: og:image PNG가 없으면 카톡/iMessage 미리보기에 이미지 없이 제목+설명만 표시됨. 기능 동작에는 영향 없음. PNG 배치 전 배포해도 viewer URL 공유는 가능하다.

---

*최종 업데이트: 2026-05-27 (STATS_KV 발급 가이드 + og:image 배치 가이드 추가)*
